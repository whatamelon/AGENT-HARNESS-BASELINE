// _shared/payment_store.ts
//
// Persistence interfaces + Supabase (service-role) implementations for the
// payment gate.
//
// H-4 / §8-A C-2: ALL writes to `orders` (amount, status, payment_key) and to
// `payment_events` go through the SERVICE-ROLE client here — never the
// client/anon key. RLS lets a user READ their own order but blocks every client
// write, so the amount and status cannot be tampered with from the app. Handlers
// depend on these interfaces; unit tests inject in-memory fakes (no live
// Supabase needed).
//
// As in store.ts, the Supabase client is consumed through a deliberately narrow
// structural interface (`OrderQueryClient`) rather than a hard SDK type import,
// so the module type-checks off the Edge runtime.

import type { OrderStatus } from "./order_state.ts";

/** An order row as the handlers need it. `amount` is the server-side SoT. */
export interface OrderRow {
  readonly id: string;
  /** Toss orderId (client-visible, unique). */
  readonly order_id: string;
  readonly user_id: string;
  /** numeric(15,2) — may arrive as number or string from PostgREST. */
  readonly amount: number | string;
  readonly currency: string;
  readonly order_name: string | null;
  readonly status: OrderStatus;
  readonly payment_key: string | null;
}

/** Server-only order persistence (service-role). */
export interface OrderStore {
  /** Insert a new pending order. Returns the created order_id. */
  insertPending(row: {
    order_id: string;
    user_id: string;
    /** numeric(15,2) string, e.g. "15000.00". */
    amount: string;
    currency: string;
    order_name: string | null;
  }): Promise<void>;

  /** Fetch an order by its Toss `order_id`, or null. */
  getByOrderId(orderId: string): Promise<OrderRow | null>;

  /**
   * Atomically move an order from `pending` to a terminal status, recording the
   * paymentKey and confirmed_at. The UPDATE is conditional on the CURRENT status
   * still being `pending` (single-statement WHERE status='pending'); it returns
   * the number of rows changed. 0 rows => the order was no longer pending (a
   * concurrent/duplicate confirm already moved it) => caller treats as no-op.
   */
  transitionFromPending(args: {
    orderId: string;
    toStatus: OrderStatus;
    paymentKey: string;
  }): Promise<number>;

  /**
   * Move a (non-pending) order to `canceled` — used by the webhook for a cancel
   * notification after the order is already confirmed. Conditional on the order
   * not already being canceled. Returns rows changed.
   */
  cancelConfirmed(orderId: string): Promise<number>;
}

/** Server-only webhook-event ledger for idempotency (service-role). */
export interface PaymentEventStore {
  /**
   * Record a processed webhook event keyed by `event_id` (unique). Returns
   * `true` if this is the FIRST time we have seen the event (insert succeeded),
   * `false` if it was a duplicate (unique violation) — the caller then skips
   * re-processing (idempotent webhook delivery).
   */
  recordIfNew(args: {
    event_id: string;
    order_id: string | null;
    type: string;
    raw: unknown;
  }): Promise<boolean>;
}

/** `{ data, error }` envelope returned by all Supabase calls we await. */
interface Result<T> {
  data: T;
  error: unknown;
}

/** Narrow structural view of the Supabase query client used by the stores. */
export interface OrderQueryClient {
  from(table: string): OrderQueryBuilder;
}

export interface OrderQueryBuilder {
  insert(values: Record<string, unknown>): OrderQueryBuilder;
  update(values: Record<string, unknown>): OrderQueryBuilder;
  select(columns: string): OrderQueryBuilder;
  eq(column: string, value: unknown): OrderQueryBuilder;
  neq(column: string, value: unknown): OrderQueryBuilder;
  maybeSingle(): PromiseLike<Result<OrderRow | null>>;
  // Terminal awaitable for insert/update; PostgREST returns affected rows when
  // a representation is requested, but we only need error + a row count proxy.
  then<R>(onfulfilled: (value: Result<unknown[] | null>) => R): PromiseLike<R>;
}

/** Back-compat alias mirroring store.ts naming. */
export type ServiceRoleClient = OrderQueryClient;

/** True when a Supabase/PostgREST error is a unique-constraint violation (23505). */
function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: unknown }).code === "23505"
  );
}

/** Count affected rows from a PostgREST `.select()`-returning write. */
function rowCount(data: unknown[] | null): number {
  return Array.isArray(data) ? data.length : 0;
}

/**
 * Supabase-backed order store. Every method uses the service-role client; RLS
 * is intentionally bypassed for these server-only writes (H-4 / §8-A C-2).
 */
export function createSupabaseOrderStore(client: OrderQueryClient): OrderStore {
  return {
    async insertPending(row) {
      const res = await client.from("orders").insert({
        order_id: row.order_id,
        user_id: row.user_id,
        amount: row.amount,
        currency: row.currency,
        order_name: row.order_name,
        status: "pending",
      });
      if (res.error) throw new Error("insertPending failed");
    },

    async getByOrderId(orderId) {
      const res = await client
        .from("orders")
        .select("id, order_id, user_id, amount, currency, order_name, status, payment_key")
        .eq("order_id", orderId)
        .maybeSingle();
      if (res.error) throw new Error("getByOrderId failed");
      return res.data;
    },

    async transitionFromPending({ orderId, toStatus, paymentKey }) {
      // Conditional atomic transition: only rows still 'pending' are updated, so
      // a duplicate confirm changes 0 rows (idempotent — no double approval).
      const res = await client
        .from("orders")
        .update({
          status: toStatus,
          payment_key: paymentKey,
          confirmed_at: new Date().toISOString(),
        })
        .eq("order_id", orderId)
        .eq("status", "pending")
        .select("id");
      if (res.error) throw new Error("transitionFromPending failed");
      return rowCount(res.data);
    },

    async cancelConfirmed(orderId) {
      const res = await client
        .from("orders")
        .update({ status: "canceled" })
        .eq("order_id", orderId)
        .neq("status", "canceled")
        .select("id");
      if (res.error) throw new Error("cancelConfirmed failed");
      return rowCount(res.data);
    },
  };
}

/** Supabase-backed webhook-event ledger. event_id unique => idempotency. */
export function createSupabasePaymentEventStore(client: OrderQueryClient): PaymentEventStore {
  return {
    async recordIfNew({ event_id, order_id, type, raw }) {
      const res = await client.from("payment_events").insert({
        event_id,
        order_id,
        type,
        raw,
        processed_at: new Date().toISOString(),
      });
      if (res.error) {
        if (isUniqueViolation(res.error)) return false; // duplicate delivery
        throw new Error("recordIfNew failed");
      }
      return true;
    },
  };
}
