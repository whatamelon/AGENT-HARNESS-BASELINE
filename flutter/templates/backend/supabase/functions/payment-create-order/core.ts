// payment-create-order/core.ts
//
// Pure, dependency-injected core for creating a payment order (§8-A C-2 — amount
// Source-of-Truth). Authentication is enforced at the handler edge (JWT ->
// userId); this core assumes an already-authenticated userId.
//
// AMOUNT SoT (the central invariant): the client NEVER supplies the amount. The
// client sends only DOMAIN intent (line items / productId / quantity). The
// server computes the authoritative amount via an injected `PriceResolver`
// (the seam where yipark wires its real products/pricing). The computed amount
// is the only value persisted on `orders.amount`, and `payment-confirm` later
// reads it back from the DB — so a tampered client amount has nowhere to enter.

import type { OrderStore } from "../_shared/payment_store.ts";
import { toNumericString } from "../_shared/money.ts";
import { buildPaymentAuditEvent, emitPaymentAudit } from "../_shared/payment_audit.ts";

/** A single requested line item (domain input from the client). */
export interface OrderLineItem {
  readonly productId: string;
  readonly quantity: number;
}

/** Result of server-side pricing: the authoritative won amount + display name. */
export interface PricedOrder {
  /** Authoritative total in whole won (integer). */
  readonly amount: number;
  /** Human-readable order name for the Toss checkout / receipt. */
  readonly orderName: string;
}

/**
 * Resolve domain input to an authoritative price. This is the integration seam:
 * the TEMPLATE provides no hard-coded catalog; yipark injects an implementation
 * backed by its `products` table (server-trusted prices) or a validated
 * line-item sum. Returning `null` means the input could not be priced (unknown
 * product / invalid quantity) -> the order is rejected.
 */
export type PriceResolver = (items: readonly OrderLineItem[]) => Promise<PricedOrder | null>;

export interface CreateOrderDeps {
  orderStore: OrderStore;
  /** Server-side price computation (amount SoT). */
  priceResolver: PriceResolver;
  /** CSPRNG-backed orderId generator (injected for deterministic tests). */
  generateOrderId: () => string;
  currency?: string; // defaults KRW
}

export interface CreateOrderResult {
  status: number;
  body:
    | { orderId: string; amount: number; orderName: string }
    | { error: string };
}

/** Validate raw client items into typed line items, or null if malformed. */
export function parseLineItems(raw: unknown): OrderLineItem[] | null {
  if (!Array.isArray(raw) || raw.length === 0) return null;
  const out: OrderLineItem[] = [];
  for (const entry of raw) {
    if (typeof entry !== "object" || entry === null) return null;
    const o = entry as Record<string, unknown>;
    const productId = o.productId;
    const quantity = o.quantity;
    if (typeof productId !== "string" || productId.length === 0) return null;
    if (typeof quantity !== "number" || !Number.isInteger(quantity) || quantity <= 0) return null;
    out.push({ productId, quantity });
  }
  return out;
}

/**
 * Core create-order logic for an authenticated user.
 *
 *   1. Parse domain line items (NOT an amount — amount is never accepted here).
 *   2. Resolve the authoritative price server-side; unpriceable -> 400.
 *   3. Generate a fresh unique orderId (CSPRNG) and INSERT a pending order with
 *      the SERVER amount + the caller's userId (service-role write).
 *   4. Return {orderId, amount, orderName} for the client to hand to the Toss
 *      widget. The returned amount is the server's, not the client's.
 */
export async function handleCreateOrder(
  userId: string,
  rawItems: unknown,
  deps: CreateOrderDeps,
): Promise<CreateOrderResult> {
  const items = parseLineItems(rawItems);
  if (!items) {
    emitPaymentAudit(buildPaymentAuditEvent({
      action: "payment_create_order",
      outcome: "invalid",
      userId,
    }));
    return { status: 400, body: { error: "invalid_items" } };
  }

  const priced = await deps.priceResolver(items);
  if (!priced || !Number.isInteger(priced.amount) || priced.amount <= 0) {
    emitPaymentAudit(buildPaymentAuditEvent({
      action: "payment_create_order",
      outcome: "invalid",
      userId,
    }));
    return { status: 400, body: { error: "unpriceable" } };
  }

  const orderId = deps.generateOrderId();
  await deps.orderStore.insertPending({
    order_id: orderId,
    user_id: userId,
    amount: toNumericString(priced.amount), // numeric(15,2) string; server SoT
    currency: deps.currency ?? "KRW",
    order_name: priced.orderName,
  });

  emitPaymentAudit(buildPaymentAuditEvent({
    action: "payment_create_order",
    outcome: "created",
    orderId,
    amount: priced.amount,
    userId,
  }));

  return {
    status: 200,
    body: { orderId, amount: priced.amount, orderName: priced.orderName },
  };
}
