// account-delete/audit.ts
//
// Structured, masked audit logging for the in-app account-deletion gate
// (Apple App Store Guideline 5.1.1(v): an app that supports account creation
// MUST let the user initiate account deletion from within the app).
//
// Every branch of the handler emits exactly one audit event. PII is MASKED
// before it ever reaches a log sink: the email is partially redacted; the IP
// loses its last octet/segment; the user-agent is truncated. The user id is the
// only stable identifier kept whole (it is an opaque uuid, not PII on its own).
//
// This local audit module mirrors the `_shared/audit.ts` (SMS) and
// `_shared/payment_audit.ts` (payments) patterns. It is kept inside the
// function dir (not `_shared`) because its action/outcome vocabulary is specific
// to account deletion; a consumer may instead swap `emitAccountAudit` for an
// `audit_logs` table insert via the service-role client (the event is already
// masked, so it is safe to persist).

export type AccountAuditAction = "account_delete";

export type AccountAuditOutcome =
  | "deleted" // account fully deleted (auth user removed)
  | "already_deleted" // idempotent: auth user no longer exists -> no-op
  | "unauthenticated" // missing/invalid JWT
  | "forbidden" // caller tried to delete a DIFFERENT user's account
  | "invalid" // malformed request body
  | "error"; // internal failure (domain cascade / auth delete threw)

export interface AccountAuditEvent {
  readonly action: AccountAuditAction;
  readonly outcome: AccountAuditOutcome;
  /** Supabase user id (opaque uuid). Kept whole — not PII on its own. */
  readonly userId?: string;
  /** Masked email, e.g. `jo****@ex****.com`. Never the full address. */
  readonly emailMasked?: string;
  /** Masked client IP, e.g. `203.0.113.*`. */
  readonly ipMasked: string;
  /** Truncated user-agent (first 80 chars) — coarse client fingerprint only. */
  readonly userAgent?: string;
  /** Number of domain rows soft-deleted across all cascade steps (best-effort). */
  readonly softDeletedRows?: number;
  /** Number of device tokens purged (push-token hygiene). */
  readonly deviceTokensPurged?: number;
  readonly at: string; // ISO timestamp
}

/**
 * Mask an email for logging: keep the first 2 chars of the local part and the
 * first 2 of the domain label, redact the rest, keep the TLD.
 * `john.doe@example.com` -> `jo****@ex****.com`. Falls back to a fully redacted
 * token for short/unexpected input so a raw address can never leak.
 */
export function maskEmail(email: string | undefined | null): string | undefined {
  if (!email) return undefined;
  const at = email.indexOf("@");
  if (at < 1) return "****";
  const local = email.slice(0, at);
  const domain = email.slice(at + 1);
  const localHead = local.slice(0, 2);
  const dot = domain.lastIndexOf(".");
  if (dot < 1) {
    return `${localHead}****@****`;
  }
  // Head is the first 2 chars of the domain label BEFORE the last dot, so a
  // short label like "b.io" yields "b" (not "b.").
  const domainHead = domain.slice(0, Math.min(2, dot));
  const tld = domain.slice(dot); // includes the leading dot
  return `${localHead}****@${domainHead}****${tld}`;
}

/**
 * Mask an IPv4/IPv6 address: drop the last octet/segment.
 * `203.0.113.42` -> `203.0.113.*`; IPv6 keeps the first 3 groups.
 * (Identical contract to `_shared/audit.ts::maskIp`.)
 */
export function maskIp(ip: string): string {
  if (!ip) return "(none)";
  if (ip.includes(".")) {
    const parts = ip.split(".");
    if (parts.length === 4) return `${parts[0]}.${parts[1]}.${parts[2]}.*`;
  }
  if (ip.includes(":")) {
    const parts = ip.split(":");
    return `${parts.slice(0, 3).join(":")}:*`;
  }
  return "*";
}

/** Truncate a user-agent so an over-long header cannot bloat the log line. */
export function truncateUserAgent(ua: string | undefined | null): string | undefined {
  if (!ua) return undefined;
  return ua.length <= 80 ? ua : `${ua.slice(0, 80)}…`;
}

/** Build a masked audit event from raw (unmasked) inputs. */
export function buildAccountAuditEvent(input: {
  outcome: AccountAuditOutcome;
  userId?: string;
  email?: string;
  ip: string;
  userAgent?: string;
  softDeletedRows?: number;
  deviceTokensPurged?: number;
}): AccountAuditEvent {
  return {
    action: "account_delete",
    outcome: input.outcome,
    userId: input.userId,
    emailMasked: maskEmail(input.email),
    ipMasked: maskIp(input.ip),
    userAgent: truncateUserAgent(input.userAgent),
    softDeletedRows: input.softDeletedRows,
    deviceTokensPurged: input.deviceTokensPurged,
    at: new Date().toISOString(),
  };
}

/**
 * Emit an audit event. The default sink is the Edge function log (structured
 * JSON). Consumers can swap this for an `audit_logs` table insert via the
 * service-role client; the event is already masked, so it is safe to persist.
 */
export function emitAccountAudit(event: AccountAuditEvent): void {
  console.log(JSON.stringify({ kind: "audit", ...event }));
}
