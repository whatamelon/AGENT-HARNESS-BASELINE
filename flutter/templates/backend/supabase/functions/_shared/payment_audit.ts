// _shared/payment_audit.ts
//
// Structured audit logging for the payment gate. Every branch of all three
// handlers emits one audit event. Sensitive identifiers are MASKED before they
// reach a log sink: paymentKey is partially redacted; raw card/PII is never
// passed in (the handlers only ever forward ids + amounts + outcome).

export type PaymentAuditAction =
  | "payment_create_order"
  | "payment_confirm"
  | "payment_webhook";

export type PaymentAuditOutcome =
  | "created"
  | "confirmed"
  | "already_confirmed"
  | "amount_mismatch"
  | "order_not_pending"
  | "not_found"
  | "forbidden"
  | "toss_error"
  | "canceled"
  | "duplicate_ignored"
  | "verification_failed"
  | "unauthenticated"
  | "invalid"
  | "error";

export interface PaymentAuditEvent {
  readonly action: PaymentAuditAction;
  readonly outcome: PaymentAuditOutcome;
  readonly orderId?: string;
  /** Masked paymentKey, e.g. `pay_****cdef`. Never the full key. */
  readonly paymentKeyMasked?: string;
  /** Server-side authoritative amount (won), when relevant. */
  readonly amount?: number;
  /** Supabase user id when the request is authenticated. */
  readonly userId?: string;
  readonly at: string; // ISO timestamp
}

/**
 * Mask a paymentKey for logging: keep a short head and the last 4, redact the
 * middle. Falls back to a fully redacted token for short input.
 */
export function maskPaymentKey(key: string | undefined | null): string | undefined {
  if (!key) return undefined;
  if (key.length <= 8) return "****";
  return `${key.slice(0, 4)}****${key.slice(-4)}`;
}

/** Build a masked audit event from raw inputs. */
export function buildPaymentAuditEvent(input: {
  action: PaymentAuditAction;
  outcome: PaymentAuditOutcome;
  orderId?: string;
  paymentKey?: string;
  amount?: number;
  userId?: string;
}): PaymentAuditEvent {
  return {
    action: input.action,
    outcome: input.outcome,
    orderId: input.orderId,
    paymentKeyMasked: maskPaymentKey(input.paymentKey),
    amount: input.amount,
    userId: input.userId,
    at: new Date().toISOString(),
  };
}

/**
 * Emit an audit event. Default sink is the Edge function log (structured JSON).
 * Consumers can swap this for an `audit_logs` table insert via the service-role
 * client; the event is already masked, so it is safe to persist.
 */
export function emitPaymentAudit(event: PaymentAuditEvent): void {
  console.log(JSON.stringify({ kind: "audit", ...event }));
}
