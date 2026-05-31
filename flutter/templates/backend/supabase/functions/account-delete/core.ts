// account-delete/core.ts
//
// Pure, dependency-injected core for in-app account deletion (Apple App Store
// Guideline 5.1.1(v): an app that supports account creation MUST offer in-app
// account deletion). Authentication is enforced at the handler edge (JWT ->
// userId); this core assumes an already-authenticated `callerId` and the
// deletion `targetId` extracted from the request. The whole point of moving the
// logic here is testability: the SMS / payment cores do the same.
//
// Invariants enforced here:
//   - SELF-ONLY: a caller may delete ONLY their own account. `targetId` (when
//     present in the body) MUST equal the authenticated `callerId`; any
//     mismatch is `forbidden` and nothing is touched. (The handler may also
//     simply trust the token's sub and never read a target from the body — both
//     paths are covered.)
//   - ORDER OF OPERATIONS: domain soft-delete and device-token purge run BEFORE
//     the auth user is removed, so a mid-flight failure leaves a still-existing
//     auth user (the client can retry) rather than an orphaned identity with
//     dangling data.
//   - IDEMPOTENCY: a repeat delete for an already-removed user is a safe no-op
//     (`already_deleted`, 200) — never an error. Each step (soft-delete,
//     token purge, auth delete) is itself idempotent.

import {
  type AccountAuditOutcome,
  buildAccountAuditEvent,
  emitAccountAudit,
} from "./audit.ts";
import type { AccountDeletionStore } from "./store.ts";

export interface DeleteAccountDeps {
  store: AccountDeletionStore;
}

export interface DeleteAccountContext {
  /** Authenticated user id from the verified JWT (`auth.getUser`). */
  callerId: string;
  /**
   * Optional target id from the request body. When provided it MUST match
   * `callerId` (self-only). When omitted, the caller's own id is used.
   */
  targetId?: string;
  /** Caller email (from the token) — masked for the audit log only. */
  email?: string;
  ip: string;
  userAgent?: string;
}

export type DeleteAccountStatus = "deleted" | "already_deleted";

export interface DeleteAccountResult {
  status: number;
  body:
    | { status: DeleteAccountStatus }
    | { error: string };
}

function audit(
  outcome: AccountAuditOutcome,
  ctx: { userId?: string; email?: string; ip: string; userAgent?: string },
  extra?: { softDeletedRows?: number; deviceTokensPurged?: number },
): void {
  emitAccountAudit(
    buildAccountAuditEvent({
      outcome,
      userId: ctx.userId,
      email: ctx.email,
      ip: ctx.ip,
      userAgent: ctx.userAgent,
      softDeletedRows: extra?.softDeletedRows,
      deviceTokensPurged: extra?.deviceTokensPurged,
    }),
  );
}

/**
 * Delete the authenticated caller's account.
 *
 *   1. Self-only check: if a `targetId` was supplied and differs from
 *      `callerId`, reject `forbidden` (403) and touch nothing.
 *   2. Idempotency: if the auth user no longer exists, return `already_deleted`
 *      (200) — a duplicate request, not an error.
 *   3. Soft-delete domain data (app-specific cascade) + purge device tokens,
 *      BEFORE removing the auth identity.
 *   4. Hard-delete the auth user (invalidates all sessions). A second concurrent
 *      delete that finds the user already gone also yields `already_deleted`.
 */
export async function handleDeleteAccount(
  ctx: DeleteAccountContext,
  deps: DeleteAccountDeps,
): Promise<DeleteAccountResult> {
  const { callerId, targetId, email, ip, userAgent } = ctx;

  // 1. Self-only authorization (defense-in-depth on top of the JWT gate).
  if (targetId != null && targetId !== callerId) {
    audit("forbidden", { userId: callerId, email, ip, userAgent });
    return { status: 403, body: { error: "forbidden" } };
  }
  const userId = callerId;

  try {
    // 2. Idempotency: already deleted -> no-op success.
    const exists = await deps.store.authUserExists(userId);
    if (!exists) {
      audit("already_deleted", { userId, email, ip, userAgent });
      return { status: 200, body: { status: "already_deleted" } };
    }

    // 3. Scrub owned data + push tokens BEFORE removing the identity.
    const softDeletedRows = await deps.store.softDeleteDomainData(userId);
    const deviceTokensPurged = await deps.store.purgeDeviceTokens(userId);

    // 4. Remove the auth identity (idempotent: false => already gone).
    const removed = await deps.store.deleteAuthUser(userId);
    if (!removed) {
      audit("already_deleted", { userId, email, ip, userAgent }, {
        softDeletedRows,
        deviceTokensPurged,
      });
      return { status: 200, body: { status: "already_deleted" } };
    }

    audit("deleted", { userId, email, ip, userAgent }, {
      softDeletedRows,
      deviceTokensPurged,
    });
    return { status: 200, body: { status: "deleted" } };
  } catch (_err) {
    // Never surface internal detail to the client; the audit log captures the
    // masked context. The auth user may still exist (delete is the last step),
    // so the client is free to retry — every step is idempotent.
    audit("error", { userId, email, ip, userAgent });
    return { status: 500, body: { error: "server_error" } };
  }
}
