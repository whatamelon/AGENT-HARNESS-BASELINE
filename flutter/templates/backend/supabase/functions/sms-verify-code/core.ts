// sms-verify-code/core.ts
//
// Pure, dependency-injected core for the verify-code flow (§8-A C-1, H-6).
// Authentication is enforced at the handler edge (JWT -> userId); this core
// assumes an already-authenticated userId and performs the constant-time check,
// attempt-cap enforcement, single-use consumption, and server-only profile
// write.

import { hashCode, timingSafeEqual } from "../_shared/code.ts";
import { isValidKrMobile, normalizeKrPhone } from "../_shared/phone.ts";
import type { VerificationStore } from "../_shared/store.ts";
import { buildAuditEvent, emitAudit } from "../_shared/audit.ts";

export type VerifyFailReason = "invalid" | "expired" | "too_many_attempts";

export interface VerifyCodeDeps {
  verificationStore: VerificationStore;
  pepper: string;
  now?: () => Date;
}

export interface VerifyCodeResult {
  status: number;
  body:
    | { verified: true }
    | { verified: false; reason: VerifyFailReason };
}

/**
 * Core verify-code logic for an authenticated user.
 *
 * Order of checks matters for safety:
 *   1. Normalize phone; bad phone -> `invalid` (no enumeration value here since
 *      the caller is already authenticated).
 *   2. Load latest unconsumed row; none / expired -> `expired`.
 *   3. Takeover binding (HIGH fix): the code's `requested_by` MUST equal the
 *      authenticated caller. A mismatch -> `invalid` WITHOUT incrementing the
 *      owner's attempt counter (so an attacker cannot lock out the real owner).
 *   4. Increment attempts ATOMICALLY; if it now exceeds the cap, consume the
 *      code and return `too_many_attempts` (lockout before comparison so a
 *      brute-forcer cannot keep guessing).
 *   5. Constant-time compare HMAC(code, pepper) vs stored hash.
 *      - match  -> consume + service-role markPhoneVerified -> {verified:true}
 *                  (markPhoneVerified=false, i.e. number already verified on
 *                   another account, also yields `invalid`).
 *      - no match -> {verified:false, reason:"invalid"}
 */
export async function handleVerifyCode(
  userId: string,
  rawPhone: string,
  code: string,
  ip: string,
  deps: VerifyCodeDeps,
): Promise<VerifyCodeResult> {
  const normalized = normalizeKrPhone(rawPhone);
  if (normalized === null || !isValidKrMobile(normalized)) {
    emitAudit(buildAuditEvent({
      action: "sms_verify_code",
      outcome: "invalid",
      phone: rawPhone,
      ip,
      userId,
    }));
    return { status: 400, body: { verified: false, reason: "invalid" } };
  }

  const row = await deps.verificationStore.latestUnconsumed(normalized);
  const now = (deps.now ?? (() => new Date()))();

  if (!row || new Date(row.expires_at).getTime() <= now.getTime()) {
    emitAudit(buildAuditEvent({
      action: "sms_verify_code",
      outcome: "expired",
      phone: normalized,
      ip,
      userId,
    }));
    return { status: 400, body: { verified: false, reason: "expired" } };
  }

  // Takeover binding (HIGH fix): the code belongs to the user who requested it.
  // A different authenticated user trying to redeem it gets `invalid`, and we do
  // NOT touch the attempt counter so the legitimate owner is not locked out.
  if (row.requested_by !== userId) {
    emitAudit(buildAuditEvent({
      action: "sms_verify_code",
      outcome: "invalid",
      phone: normalized,
      ip,
      userId,
    }));
    return { status: 400, body: { verified: false, reason: "invalid" } };
  }

  // Atomic attempt increment BEFORE comparison; lock out on cap breach.
  const attempts = await deps.verificationStore.incrementAttempts(row.id);
  if (attempts > row.max_attempts) {
    await deps.verificationStore.consume(row.id); // burn the code on lockout
    emitAudit(buildAuditEvent({
      action: "sms_verify_code",
      outcome: "too_many_attempts",
      phone: normalized,
      ip,
      userId,
    }));
    return { status: 400, body: { verified: false, reason: "too_many_attempts" } };
  }

  const candidateHash = await hashCode(code, deps.pepper);
  if (!timingSafeEqual(candidateHash, row.code_hash)) {
    emitAudit(buildAuditEvent({
      action: "sms_verify_code",
      outcome: "invalid",
      phone: normalized,
      ip,
      userId,
    }));
    return { status: 400, body: { verified: false, reason: "invalid" } };
  }

  // Success: single-use consume + server-only verified flag (H-6).
  await deps.verificationStore.consume(row.id);
  const marked = await deps.verificationStore.markPhoneVerified(userId, normalized);
  if (!marked) {
    // Number already verified on a DIFFERENT account
    // (uq_profiles_phone_verified). The code was correct but cannot be bound
    // here -> not verified. Code is already consumed above (single-use).
    emitAudit(buildAuditEvent({
      action: "sms_verify_code",
      outcome: "invalid",
      phone: normalized,
      ip,
      userId,
    }));
    return { status: 400, body: { verified: false, reason: "invalid" } };
  }
  emitAudit(buildAuditEvent({
    action: "sms_verify_code",
    outcome: "verified",
    phone: normalized,
    ip,
    userId,
  }));
  return { status: 200, body: { verified: true } };
}
