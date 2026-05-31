// payment-confirm/core.test.ts — §8-A C-2: amount SoT, idempotency, ownership.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleConfirm } from "./core.ts";
import type { OrderStore, OrderRow } from "../_shared/payment_store.ts";
import type { TossClient, TossResult } from "../_shared/toss_client.ts";
import type { OrderStatus } from "../_shared/order_state.ts";

const USER = "user-1";

interface OrderOpts {
  status?: OrderStatus;
  amount?: number | string;
  userId?: string;
  noRow?: boolean;
}

class FakeOrderStore implements OrderStore {
  public transitioned: Array<{ orderId: string; toStatus: OrderStatus; paymentKey: string }> = [];
  /** When >0, the first N transitionFromPending calls return 0 (already moved). */
  public forceNoRows = 0;
  private row: OrderRow | null;

  constructor(opts: OrderOpts) {
    this.row = opts.noRow ? null : {
      id: "row-1",
      order_id: "order-1",
      user_id: opts.userId ?? USER,
      amount: opts.amount ?? "15000.00",
      currency: "KRW",
      order_name: "상품",
      status: opts.status ?? "pending",
      payment_key: null,
    };
  }
  insertPending(): Promise<void> { return Promise.resolve(); }
  getByOrderId(): Promise<OrderRow | null> { return Promise.resolve(this.row); }
  transitionFromPending(args: { orderId: string; toStatus: OrderStatus; paymentKey: string }): Promise<number> {
    this.transitioned.push(args);
    if (this.forceNoRows > 0) { this.forceNoRows -= 1; return Promise.resolve(0); }
    return Promise.resolve(1);
  }
  cancelConfirmed(): Promise<number> { return Promise.resolve(0); }
}

/** Toss client that returns a fixed confirm result and records the call. */
function fakeToss(result: TossResult): { client: TossClient; calls: Array<{ amount: number; idempotencyKey: string }> } {
  const calls: Array<{ amount: number; idempotencyKey: string }> = [];
  const client: TossClient = {
    confirmPayment(args) { calls.push({ amount: args.amount, idempotencyKey: args.idempotencyKey }); return Promise.resolve(result); },
    getPayment() { return Promise.resolve(result); },
  };
  return { client, calls };
}

function tossOk(totalAmount: number, status = "DONE"): TossResult {
  return { ok: true, payment: { paymentKey: "pk1", orderId: "order-1", status, totalAmount } };
}

Deno.test("confirm: happy path -> uses DB amount, sends Idempotency-Key=orderId, confirms", async () => {
  const store = new FakeOrderStore({ amount: "15000.00" });
  const toss = fakeToss(tossOk(15000));
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "confirmed", orderId: "order-1" });
  // The amount sent to Toss is the DB SoT (15000), not anything client-supplied.
  assertEquals(toss.calls[0].amount, 15000);
  assertEquals(toss.calls[0].idempotencyKey, "order-1");
  assertEquals(store.transitioned[0], { orderId: "order-1", toStatus: "confirmed", paymentKey: "pk1" });
});

Deno.test("confirm: client forging amount has NO effect — handler never accepts an amount param", async () => {
  // handleConfirm's signature is (userId, orderId, paymentKey, deps): there is
  // structurally no client amount input. The amount sent to Toss is the DB's.
  const store = new FakeOrderStore({ amount: 15000 }); // DB number form
  const toss = fakeToss(tossOk(15000));
  await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(toss.calls[0].amount, 15000);
});

Deno.test("confirm: Toss response amount != DB amount -> amount_mismatch 409 (tamper block)", async () => {
  const store = new FakeOrderStore({ amount: "15000.00" });
  const toss = fakeToss(tossOk(14999)); // Toss says a different amount
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 409);
  assertEquals(res.body, { status: "amount_mismatch" });
  assertEquals(store.transitioned.length, 0); // no state change on mismatch
});

Deno.test("confirm: re-confirm already-confirmed order -> idempotent already_confirmed (no double approval)", async () => {
  const store = new FakeOrderStore({ status: "confirmed" });
  const toss = fakeToss(tossOk(15000));
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "already_confirmed", orderId: "order-1" });
  assertEquals(toss.calls.length, 0);        // never re-charges Toss
  assertEquals(store.transitioned.length, 0); // never re-transitions
});

Deno.test("confirm: concurrent winner already moved row (0 rows changed) -> already_confirmed", async () => {
  const store = new FakeOrderStore({ status: "pending", amount: "15000.00" });
  store.forceNoRows = 1; // simulate a concurrent confirm winning the race
  const toss = fakeToss(tossOk(15000));
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "already_confirmed", orderId: "order-1" });
});

Deno.test("confirm: non-pending (canceled) order -> order_not_pending 409", async () => {
  const store = new FakeOrderStore({ status: "canceled" });
  const toss = fakeToss(tossOk(15000));
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 409);
  assertEquals(res.body, { status: "order_not_pending" });
  assertEquals(toss.calls.length, 0);
});

Deno.test("confirm: another user's order -> forbidden 403", async () => {
  const store = new FakeOrderStore({ userId: "owner", status: "pending" });
  const toss = fakeToss(tossOk(15000));
  const res = await handleConfirm("attacker", "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 403);
  assertEquals(toss.calls.length, 0);
});

Deno.test("confirm: order not found -> 404", async () => {
  const store = new FakeOrderStore({ noRow: true });
  const toss = fakeToss(tossOk(15000));
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 404);
  assertEquals(toss.calls.length, 0);
});

Deno.test("confirm: Toss error -> 502, order stays pending (no transition)", async () => {
  const store = new FakeOrderStore({ status: "pending" });
  const toss = fakeToss({ ok: false, error: { httpStatus: 400, code: "REJECT_CARD_COMPANY", message: "x" } });
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 502);
  assertEquals(store.transitioned.length, 0);
});

Deno.test("confirm: Toss returns unexpected status (not DONE/cancel/etc on pending) -> 502", async () => {
  const store = new FakeOrderStore({ status: "pending", amount: "15000.00" });
  const toss = fakeToss(tossOk(15000, "BIZARRE_STATUS"));
  const res = await handleConfirm(USER, "order-1", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 502);
  assertEquals(store.transitioned.length, 0);
});

Deno.test("confirm: missing orderId/paymentKey -> 400", async () => {
  const store = new FakeOrderStore({ status: "pending" });
  const toss = fakeToss(tossOk(15000));
  const res = await handleConfirm(USER, "", "pk1", { orderStore: store, tossClient: toss.client });
  assertEquals(res.status, 400);
});
