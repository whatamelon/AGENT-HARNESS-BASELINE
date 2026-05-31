// payment-webhook/core.test.ts — authenticity re-fetch + idempotency.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { extractWebhookPaymentKey, extractWebhookType, handleWebhook } from "./core.ts";
import type { OrderStore, OrderRow, PaymentEventStore } from "../_shared/payment_store.ts";
import type { TossClient, TossResult } from "../_shared/toss_client.ts";
import type { OrderStatus } from "../_shared/order_state.ts";

function fakeOrderRow(orderId: string, amount: number | string): OrderRow {
  return {
    id: `id-${orderId}`,
    order_id: orderId,
    user_id: "user-1",
    amount,
    currency: "KRW",
    order_name: "test order",
    status: "pending",
    payment_key: null,
  };
}

class FakeOrderStore implements OrderStore {
  public confirmed: string[] = [];
  public canceled: string[] = [];
  /** orderId -> order row served by getByOrderId. Defaults to a 15000-won match. */
  private readonly orders = new Map<string, OrderRow>();
  /** When set, transitionFromPending reports this many changed rows. */
  public transitionRows = 1;
  constructor(orders: readonly OrderRow[] = [fakeOrderRow("order-1", 15000)]) {
    for (const o of orders) this.orders.set(o.order_id, o);
  }
  insertPending(): Promise<void> { return Promise.resolve(); }
  getByOrderId(orderId: string): Promise<OrderRow | null> {
    return Promise.resolve(this.orders.get(orderId) ?? null);
  }
  transitionFromPending(args: { orderId: string; toStatus: OrderStatus }): Promise<number> {
    if (args.toStatus === "confirmed" && this.transitionRows > 0) this.confirmed.push(args.orderId);
    return Promise.resolve(this.transitionRows);
  }
  cancelConfirmed(orderId: string): Promise<number> { this.canceled.push(orderId); return Promise.resolve(1); }
}

class FakeEventStore implements PaymentEventStore {
  public seen = new Set<string>();
  public recorded: string[] = [];
  recordIfNew(args: { event_id: string }): Promise<boolean> {
    if (this.seen.has(args.event_id)) return Promise.resolve(false);
    this.seen.add(args.event_id);
    this.recorded.push(args.event_id);
    return Promise.resolve(true);
  }
}

function fakeToss(result: TossResult): { client: TossClient; getCalls: string[] } {
  const getCalls: string[] = [];
  const client: TossClient = {
    confirmPayment() { return Promise.resolve(result); },
    getPayment(pk) { getCalls.push(pk); return Promise.resolve(result); },
  };
  return { client, getCalls };
}

function tossOk(orderId: string, status: string, totalAmount = 15000): TossResult {
  return { ok: true, payment: { paymentKey: "pk1", orderId, status, totalAmount } };
}

function webhookBody(paymentKey: string, status = "DONE") {
  return { eventType: "PAYMENT_STATUS_CHANGED", createdAt: "2026-01-01T00:00:00.000000", data: { paymentKey, status } };
}

Deno.test("extractWebhookPaymentKey / extractWebhookType", () => {
  assertEquals(extractWebhookPaymentKey(webhookBody("pkX")), "pkX");
  assertEquals(extractWebhookPaymentKey({ data: {} }), null);
  assertEquals(extractWebhookPaymentKey(null), null);
  assertEquals(extractWebhookType(webhookBody("pkX")), "PAYMENT_STATUS_CHANGED");
  assertEquals(extractWebhookType({}), "UNKNOWN");
});

Deno.test("webhook: re-fetches authoritative status (does NOT trust body) and confirms on DONE", async () => {
  const store = new FakeOrderStore();
  const events = new FakeEventStore();
  // Body claims DONE; authoritative Toss also DONE for order-1.
  const toss = fakeToss(tossOk("order-1", "DONE"));
  const res = await handleWebhook(webhookBody("pk1", "DONE"), { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "ok" });
  assertEquals(toss.getCalls, ["pk1"]);       // authenticity gate: re-fetched
  assertEquals(store.confirmed, ["order-1"]); // from AUTHORITATIVE status
});

Deno.test("webhook: body LIES (says DONE) but authoritative Toss says canceled -> order canceled, not confirmed", async () => {
  const store = new FakeOrderStore();
  const events = new FakeEventStore();
  // Forged-ish body claims DONE; Toss authoritative is CANCELED. Authoritative wins.
  const toss = fakeToss(tossOk("order-1", "CANCELED"));
  const res = await handleWebhook(webhookBody("pk1", "DONE"), { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(store.confirmed, []);          // body's DONE ignored
  assertEquals(store.canceled, ["order-1"]);  // authoritative CANCELED applied
});

Deno.test("webhook: getPayment fails (forged/unknown key) -> 401 verification_failed, NO state change", async () => {
  const store = new FakeOrderStore();
  const events = new FakeEventStore();
  const toss = fakeToss({ ok: false, error: { httpStatus: 404, code: "NOT_FOUND_PAYMENT", message: "x" } });
  const res = await handleWebhook(webhookBody("forged"), { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 401);
  assertEquals(store.confirmed, []);
  assertEquals(store.canceled, []);
  assertEquals(events.recorded, []); // nothing recorded for an unverifiable event
});

Deno.test("webhook: duplicate event_id (paymentKey+status) -> 200 ignored, no re-processing", async () => {
  const store = new FakeOrderStore();
  const events = new FakeEventStore();
  const toss = fakeToss(tossOk("order-1", "DONE"));
  const deps = { orderStore: store, paymentEventStore: events, tossClient: toss.client };

  const first = await handleWebhook(webhookBody("pk1", "DONE"), deps);
  const second = await handleWebhook(webhookBody("pk1", "DONE"), deps);
  assertEquals(first.body, { status: "ok" });
  assertEquals(second.body, { status: "ignored" });
  assertEquals(store.confirmed, ["order-1"]); // confirmed exactly once
});

Deno.test("webhook: missing paymentKey in body -> 400 invalid", async () => {
  const store = new FakeOrderStore();
  const events = new FakeEventStore();
  const toss = fakeToss(tossOk("order-1", "DONE"));
  const res = await handleWebhook({ eventType: "PAYMENT_STATUS_CHANGED", data: {} }, { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 400);
  assertEquals(toss.getCalls, []); // never even re-fetched
});

Deno.test("webhook: authoritative still-pending status (WAITING_FOR_DEPOSIT) -> recorded, no transition", async () => {
  const store = new FakeOrderStore();
  const events = new FakeEventStore();
  const toss = fakeToss(tossOk("order-1", "WAITING_FOR_DEPOSIT"));
  const res = await handleWebhook(webhookBody("pk1"), { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(store.confirmed, []);
  assertEquals(store.canceled, []);
  assertEquals(events.recorded.length, 1); // event still recorded for idempotency
});

Deno.test("webhook: authoritative totalAmount != DB orders.amount on DONE -> NO confirm, ignored + amount_mismatch (tamper block)", async () => {
  // Server-side order is for 15,000 won; Toss authoritative says it charged 9,999.
  const store = new FakeOrderStore([fakeOrderRow("order-1", 15000)]);
  const events = new FakeEventStore();
  const toss = fakeToss(tossOk("order-1", "DONE", 9999));
  const res = await handleWebhook(webhookBody("pk1", "DONE"), { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "ignored" }); // 200 so Toss does not retry a permanent discrepancy
  assertEquals(store.confirmed, []);              // money invariant held: no confirmation on mismatch
  assertEquals(store.canceled, []);
});

Deno.test("webhook: authoritative totalAmount == DB orders.amount on DONE -> confirmed (unchanged happy path)", async () => {
  const store = new FakeOrderStore([fakeOrderRow("order-1", "15000.00")]); // numeric(15,2) string form
  const events = new FakeEventStore();
  const toss = fakeToss(tossOk("order-1", "DONE", 15000));
  const res = await handleWebhook(webhookBody("pk1", "DONE"), { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "ok" });
  assertEquals(store.confirmed, ["order-1"]);
});

Deno.test("webhook: DONE for a non-existent orderId -> safe, no state change, no false confirm audit", async () => {
  // Authoritative Toss resolves to an orderId we have no row for. There is
  // nothing to confirm: make no transition (count 0) and do NOT log a confirm.
  const store = new FakeOrderStore([]); // empty: getByOrderId -> null
  store.transitionRows = 0;             // belt-and-suspenders: would-be transition is a no-op
  const events = new FakeEventStore();
  const toss = fakeToss(tossOk("ghost-order", "DONE", 15000));
  const res = await handleWebhook(webhookBody("pk1", "DONE"), { orderStore: store, paymentEventStore: events, tossClient: toss.client });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "ignored" });
  assertEquals(store.confirmed, []); // no confirmation, no mis-logged confirm
  assertEquals(store.canceled, []);
});
