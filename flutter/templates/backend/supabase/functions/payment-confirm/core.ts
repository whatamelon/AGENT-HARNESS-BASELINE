// payment-confirm/core.ts
//
// Pure, dependency-injected core for confirming a payment — the heart of §8-A
// C-2 (amount SoT + idempotency + webhook-independent state machine).
// Authentication is enforced at the handler edge (JWT -> userId).
//
// Invariants enforced here:
//   - AMOUNT SoT: the client body has NO amount. The amount sent to Toss is the
//     order's DB amount, and the Toss response amount is compared back against
//     it (amount_mismatch -> reject). A tampered client value cannot enter.
//   - OWNERSHIP: the order must belong to the authenticated caller.
//   - IDEMPOTENCY: a repeat confirm is a no-op. We carry an `Idempotency-Key`
//     (orderId) to Toss AND perform a conditional `pending -> confirmed`
//     transition in the DB; a second call changes 0 rows -> already_confirmed.
//   - STATE MACHINE: only a `pending` order may be confirmed.

import type { OrderStore } from "../_shared/payment_store.ts";
import type { TossClient } from "../_shared/toss_client.ts";
import { amountsEqual, parseKrwAmount } from "../_shared/money.ts";
import { canTransition, mapTossStatus } from "../_shared/order_state.ts";
import { buildPaymentAuditEvent, emitPaymentAudit } from "../_shared/payment_audit.ts";

export type ConfirmStatus =
  | "confirmed"
  | "already_confirmed"
  | "amount_mismatch"
  | "order_not_pending";

export interface ConfirmDeps {
  orderStore: OrderStore;
  tossClient: TossClient;
}

export interface ConfirmResult {
  status: number;
  body:
    | { status: "confirmed"; orderId: string }
    | { status: "already_confirmed"; orderId: string }
    | { status: ConfirmStatus }
    | { error: string };
}

/**
 * Confirm a payment for an authenticated user.
 *
 *   1. Load the order by orderId. Not found OR not owned by the caller -> reject
 *      (404/403). Ownership is checked before anything else leaks.
 *   2. If the order is already `confirmed` for THIS paymentKey, return an
 *      idempotent `already_confirmed` (200) — a duplicate confirm, not an error.
 *   3. If the order is not `pending` (and not the already-confirmed case above),
 *      reject `order_not_pending` (409).
 *   4. serverAmount = order.amount (DB SoT). Call Toss confirm with serverAmount
 *      + `Idempotency-Key: orderId`.
 *   5. Toss success: response amount MUST equal serverAmount, else
 *      `amount_mismatch` (409, tamper block). Map Toss status (DONE->confirmed)
 *      and atomically transition pending->confirmed (conditional UPDATE). If the
 *      conditional update changed 0 rows, a concurrent confirm won -> idempotent
 *      `already_confirmed`.
 *   6. Toss failure -> surface a toss_error (the order stays pending; the client
 *      may retry, and the Idempotency-Key keeps Toss side single-charge).
 */
export async function handleConfirm(
  userId: string,
  orderId: string,
  paymentKey: string,
  deps: ConfirmDeps,
): Promise<ConfirmResult> {
  if (!orderId || !paymentKey) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "invalid", userId, orderId, paymentKey }));
    return { status: 400, body: { error: "invalid" } };
  }

  const order = await deps.orderStore.getByOrderId(orderId);
  if (!order) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "not_found", userId, orderId, paymentKey }));
    return { status: 404, body: { error: "not_found" } };
  }
  if (order.user_id !== userId) {
    // Do not reveal order existence detail beyond forbidden.
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "forbidden", userId, orderId, paymentKey }));
    return { status: 403, body: { error: "forbidden" } };
  }

  // Idempotent re-confirm: order already confirmed (optionally with same key).
  if (order.status === "confirmed") {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "already_confirmed", userId, orderId, paymentKey }));
    return { status: 200, body: { status: "already_confirmed", orderId } };
  }

  if (order.status !== "pending") {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "order_not_pending", userId, orderId, paymentKey }));
    return { status: 409, body: { status: "order_not_pending" } };
  }

  const serverAmount = parseKrwAmount(order.amount);
  if (serverAmount === null) {
    // Corrupt stored amount — refuse rather than send a bad value to Toss.
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "error", userId, orderId, paymentKey }));
    return { status: 500, body: { error: "server_error" } };
  }

  // Confirm with the SERVER amount + idempotency key (orderId).
  const result = await deps.tossClient.confirmPayment({
    paymentKey,
    orderId,
    amount: serverAmount,
    idempotencyKey: orderId,
  });

  if (!result.ok) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "toss_error", userId, orderId, paymentKey, amount: serverAmount }));
    return { status: 502, body: { error: "toss_error" } };
  }

  const payment = result.payment;

  // Tamper block: the amount Toss charged MUST equal the server order amount.
  if (!amountsEqual(payment.totalAmount, serverAmount)) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "amount_mismatch", userId, orderId, paymentKey, amount: serverAmount }));
    return { status: 409, body: { status: "amount_mismatch" } };
  }

  const mapped = mapTossStatus(payment.status);
  if (mapped === null || !canTransition("pending", mapped)) {
    // Unknown/illegal Toss status for a pending confirm — do not move blindly.
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "toss_error", userId, orderId, paymentKey, amount: serverAmount }));
    return { status: 502, body: { error: "toss_error" } };
  }

  // Atomic conditional transition pending->mapped. 0 rows => a concurrent
  // confirm already moved it (idempotent already_confirmed).
  const changed = await deps.orderStore.transitionFromPending({
    orderId,
    toStatus: mapped,
    paymentKey,
  });
  if (changed === 0) {
    emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "already_confirmed", userId, orderId, paymentKey, amount: serverAmount }));
    return { status: 200, body: { status: "already_confirmed", orderId } };
  }

  emitPaymentAudit(buildPaymentAuditEvent({ action: "payment_confirm", outcome: "confirmed", userId, orderId, paymentKey, amount: serverAmount }));
  return { status: 200, body: { status: "confirmed", orderId } };
}
