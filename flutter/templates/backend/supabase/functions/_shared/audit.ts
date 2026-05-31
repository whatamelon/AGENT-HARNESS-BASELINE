// _shared/audit.ts
//
// Structured audit logging for the SMS auth gate. Every branch of both handlers
// emits one audit event. Sensitive fields are MASKED before they ever reach a
// log sink (codes are never logged at all; phones are partially redacted).

export type SmsAuditAction =
  | "sms_request_code"
  | "sms_verify_code";

export type SmsAuditOutcome =
  | "sent"
  | "suppressed_invalid_phone"
  | "suppressed_not_allowed"
  | "rate_limited"
  | "verified"
  | "invalid"
  | "expired"
  | "too_many_attempts"
  | "unauthenticated"
  | "error";

export interface SmsAuditEvent {
  readonly action: SmsAuditAction;
  readonly outcome: SmsAuditOutcome;
  /** Masked phone, e.g. `+8210****5678`. Never the full number. */
  readonly phoneMasked: string;
  /** Masked client IP, e.g. `203.0.113.*`. */
  readonly ipMasked: string;
  /** Supabase user id when the request is authenticated (verify path). */
  readonly userId?: string;
  /** Rule name when rate-limited. */
  readonly exceededRule?: string;
  readonly at: string; // ISO timestamp
}

/**
 * Mask a phone for logging: keep country/prefix head and last 4, redact middle.
 * `+821012345678` -> `+8210****5678`. Falls back to a fully redacted token for
 * short/unexpected input so a raw number can never leak via the log path.
 */
export function maskPhone(phone: string): string {
  if (!phone) return "(none)";
  if (phone.length <= 8) return "****";
  const head = phone.slice(0, 5); // e.g. +8210
  const tail = phone.slice(-4);
  return `${head}****${tail}`;
}

/**
 * Mask an IPv4/IPv6 address: drop the last octet/segment.
 * `203.0.113.42` -> `203.0.113.*`; IPv6 keeps the first 3 groups.
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

/** Build a masked audit event from raw (unmasked) inputs. */
export function buildAuditEvent(input: {
  action: SmsAuditAction;
  outcome: SmsAuditOutcome;
  phone: string;
  ip: string;
  userId?: string;
  exceededRule?: string;
}): SmsAuditEvent {
  return {
    action: input.action,
    outcome: input.outcome,
    phoneMasked: maskPhone(input.phone),
    ipMasked: maskIp(input.ip),
    userId: input.userId,
    exceededRule: input.exceededRule,
    at: new Date().toISOString(),
  };
}

/**
 * Emit an audit event. The default sink is the Edge function log (structured
 * JSON). Consumers can swap this for an `audit_logs` table insert via the
 * service-role client; the event is already masked, so it is safe to persist.
 */
export function emitAudit(event: SmsAuditEvent): void {
  // Structured single-line JSON so log processors can index it.
  console.log(JSON.stringify({ kind: "audit", ...event }));
}
