// payment-webhook/core.ts
//
// Pure, dependency-injected core for the Toss webhook (§8-A C-2 — authenticity
// verification + idempotency). This handler is NOT authenticated by a user JWT;
// it is called by Toss. Two defenses make it safe despite that:
//
//   AUTHENTICITY (webhook body is NOT trusted): the PAYMENT_STATUS_CHANGED
//   webhook carries no signature header, so its body could be forged. We extract
//   ONLY the paymentKey from the body, then re-fetch the authoritative payment
//   via Toss `GET /v1/payments/{paymentKey}` (Basic-authed with the server
//   secret). The Toss API response — not the webhook body — drives every state
//   change. A forged body whose paymentKey does not resolve at Toss is ignored.
//
//   IDEMPOTENCY: each delivery is keyed by an `event_id` (paymentKey + the
//   authoritative status). `recordIfNew` uses a UNIQUE constraint so a duplicate
//   delivery is a no-op.
//
// We return 200 ONLY on a successfully processed (or safely-ignored-as-duplicate)
// event so Toss does not retry a genuinely-handled event; verification failures
// return non-200.

import type { OrderStore, PaymentEventStore } from "../_shared/payment_store.ts";
import type { TossClient } from "../_shared/toss_client.ts";
import { mapTossStatus } from "../_shared/order_state.ts";
import { amountsEqual } from "../_shared/money.ts";
import { buildPaymentAuditEvent, emitPaymentAudit } from "../_shared/payment_audit.ts";

export interface WebhookDeps {
  orderStore: OrderStore;
  paymentEventStore: PaymentEventStore;
  tossClient: TossClient;
}

export interface WebhookResult {
  status: number;
  body: { status: "ok" } | { status: "ignored" } | { error: string };
}

/** Extract the paymentKey from an (untrusted) webhook body. */
export function extractWebhookPaymentKey(body: unknown): string | null {
  if (typeof body !== "object" || body === null) return null;
  const o = body as Record<string, unknown>;
  const data = o.data;
  if (typeof data !== "object" || data === null) return null;
  const paymentKey = (data as Record<string, unknown>).paymentKey;
  return typeof paymentKey === "string" && paymentKey.length > 0 ? paymentKey : null;
}

/** Extract the eventType from an (untrusted) webhook body, for the audit/type. */
export function extractWebhookType(body: unknown): string {
  if (typeof body === "object" && body !== null) {
    const t = (body as Record<string, unknown>).eventType;
    if (typeof t === "string") return t;
  }
  return "UNKNOWN";
}

/**
 * Process a Toss webhook delivery.
 *
 *   1. Pull paymentKey from the (untrusted) body. Missing -> 400 invalid.
 *   2. Re-fetch the authoritative payment from Toss (authenticity gate). A
 *      failed fetch (forged/unknown key, Toss error) -> 401 verification_failed,
 *      NO state change.
 *   3. Build a deterministic event_id = `paymentKey:authoritativeStatus` and
 *      record it; a duplicate (already recorded) -> 200 ignored (idempotent).
 *   4. Apply the AUTHORITATIVE status to the order:
 *        DONE  -> confirm a still-pending order (deposit received / paid), but
 *                 ONLY when the authoritative Toss `totalAmount` equals the
 *                 server-side `orders.amount` (same amount invariant as the
 *                 confirm endpoint — a mismatch is a tamper signal and is
 *                 ignored without any state change). A missing order is treated
 *                 the same way (nothing to confirm).
 *        CANCELED/PARTIAL_CANCELED -> cancel the order.
 *      Other statuses (still pending) are recorded but cause no transition.
 */
export async function handleWebhook(
  rawBody: unknown,
  deps: WebhookDeps,
): Promise<WebhookResult> {
  const type = extractWebhookType(rawBody);
  const paymentKey = extractWebhookPaymentKey(rawBody);
  if (!paymentKey) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_webhook", outcome: "invalid" }));
    return { status: 400, body: { error: "invalid" } };
  }

  // AUTHENTICITY: never trust the body — fetch the authoritative state.
  const authoritative = await deps.tossClient.getPayment(paymentKey);
  if (!authoritative.ok) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_webhook", outcome: "verification_failed", paymentKey }));
    return { status: 401, body: { error: "verification_failed" } };
  }
  const payment = authoritative.payment;
  const orderId = payment.orderId;

  // IDEMPOTENCY: dedupe on (paymentKey + authoritative status). A repeat
  // delivery for the same transition is ignored.
  const eventId = `${paymentKey}:${payment.status}`;
  const isNew = await deps.paymentEventStore.recordIfNew({
    event_id: eventId,
    order_id: orderId,
    type,
    raw: { authoritativeStatus: payment.status, totalAmount: payment.totalAmount },
  });
  if (!isNew) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_webhook", outcome: "duplicate_ignored", orderId, paymentKey }));
    return { status: 200, body: { status: "ignored" } };
  }

  const mapped = mapTossStatus(payment.status);
  if (mapped === "confirmed") {
    // Tamper block (same invariant as the confirm endpoint): the AUTHORITATIVE
    // Toss `totalAmount` MUST equal the server-side `orders.amount`. A missing
    // order or an amount mismatch is a tamper signal — make NO state change,
    // audit `amount_mismatch`, and return 200 `ignored` so Toss does not retry
    // (the discrepancy is permanent, not transient).
    const order = await deps.orderStore.getByOrderId(orderId);
    if (!order || !amountsEqual(payment.totalAmount, order.amount)) {
      emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_webhook", outcome: "amount_mismatch", orderId, paymentKey, amount: payment.totalAmount }));
      return { status: 200, body: { status: "ignored" } };
    }
    // Deposit received / paid: confirm a still-pending order. The conditional
    // transition changes 0 rows if already confirmed (confirm endpoint or a
    // prior delivery) — distinguish confirmed vs duplicate by the row count so
    // a no-op is not mis-logged as a fresh confirmation.
    const changed = await deps.orderStore.transitionFromPending({ orderId, toStatus: "confirmed", paymentKey });
    emitPaymentAudit(buildPaymentAuditEvent({
      action: "payment_webhook",
      outcome: changed > 0 ? "confirmed" : "duplicate_ignored",
      orderId,
      paymentKey,
      amount: payment.totalAmount,
    }));
    return { status: 200, body: { status: "ok" } };
  }
  if (mapped === "canceled") {
    await deps.orderStore.cancelConfirmed(orderId);
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_webhook", outcome: "canceled", orderId, paymentKey }));
    return { status: 200, body: { status: "ok" } };
  }

  // pending / unknown authoritative status -> recorded, no transition.
  emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_webhook", outcome: mapped === null ? "error" : "duplicate_ignored", orderId, paymentKey }));
  return { status: 200, body: { status: "ok" } };
}
