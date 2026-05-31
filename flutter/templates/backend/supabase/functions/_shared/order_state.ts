// _shared/order_state.ts
//
// Order payment state machine (§8-A C-2 — idempotency via a strict transition
// matrix). The internal order status is a SMALL, server-controlled enum that is
// distinct from Toss's payment status; `mapTossStatus` projects an authoritative
// Toss status onto our enum.
//
// Allowed transitions (and ONLY these):
//   pending   -> confirmed | canceled | failed
//   confirmed -> canceled            (post-confirm refund/cancel)
//   canceled  -> (terminal)
//   failed    -> (terminal)
//
// Re-entry into `confirmed` from `confirmed` is BLOCKED here so the confirm
// handler treats a repeat confirm as an idempotent no-op rather than a second
// approval (double-charge guard). The DB also enforces single-confirm via the
// conditional `status = 'pending'` UPDATE.

export type OrderStatus = "pending" | "confirmed" | "canceled" | "failed";

export const ORDER_STATUSES: readonly OrderStatus[] = [
  "pending",
  "confirmed",
  "canceled",
  "failed",
] as const;

/** Type guard for an arbitrary string against the order status enum. */
export function isOrderStatus(value: unknown): value is OrderStatus {
  return typeof value === "string" && (ORDER_STATUSES as readonly string[]).includes(value);
}

/** Adjacency matrix of permitted transitions. */
const TRANSITIONS: Readonly<Record<OrderStatus, readonly OrderStatus[]>> = {
  pending: ["confirmed", "canceled", "failed"],
  confirmed: ["canceled"],
  canceled: [],
  failed: [],
};

/**
 * True iff `from -> to` is a permitted transition. A self-transition (e.g.
 * confirmed->confirmed) is NOT permitted — callers must detect "already in the
 * target state" separately and treat it as an idempotent no-op, not a move.
 */
export function canTransition(from: OrderStatus, to: OrderStatus): boolean {
  return TRANSITIONS[from].includes(to);
}

/**
 * Project an authoritative Toss payment status onto our internal order status.
 *
 * Toss one-time payment statuses (PAYMENT_STATUS_CHANGED / GET payment):
 *   READY, IN_PROGRESS, WAITING_FOR_DEPOSIT -> still pending (no money moved yet)
 *   DONE                                    -> confirmed (paid / deposit received)
 *   CANCELED, PARTIAL_CANCELED              -> canceled
 *   ABORTED, EXPIRED                        -> failed
 *
 * Returns `null` for an unknown status so the caller can refuse to act on a
 * value it does not understand (fail-closed).
 */
export function mapTossStatus(tossStatus: string): OrderStatus | null {
  switch (tossStatus) {
    case "DONE":
      return "confirmed";
    case "CANCELED":
    case "PARTIAL_CANCELED":
      return "canceled";
    case "ABORTED":
    case "EXPIRED":
      return "failed";
    case "READY":
    case "IN_PROGRESS":
    case "WAITING_FOR_DEPOSIT":
      return "pending";
    default:
      return null;
  }
}
