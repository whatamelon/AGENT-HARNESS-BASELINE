// payment-create-order/core.test.ts — amount SoT (client amount ignored).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleCreateOrder, parseLineItems, type PricedOrder } from "./core.ts";
import type { OrderStore, OrderRow } from "../_shared/payment_store.ts";

const USER = "user-1";

class FakeOrderStore implements OrderStore {
  public inserted: Array<{ order_id: string; user_id: string; amount: string; currency: string; order_name: string | null }> = [];
  insertPending(row: { order_id: string; user_id: string; amount: string; currency: string; order_name: string | null }): Promise<void> {
    this.inserted.push(row);
    return Promise.resolve();
  }
  getByOrderId(): Promise<OrderRow | null> { return Promise.resolve(null); }
  transitionFromPending(): Promise<number> { return Promise.resolve(0); }
  cancelConfirmed(): Promise<number> { return Promise.resolve(0); }
}

/** Price resolver that always prices to 15000 won regardless of the input. */
function fixedResolver(amount: number, orderName = "테스트 상품"): () => Promise<PricedOrder | null> {
  return () => Promise.resolve({ amount, orderName });
}

Deno.test("parseLineItems: valid items", () => {
  assertEquals(parseLineItems([{ productId: "p1", quantity: 2 }]), [{ productId: "p1", quantity: 2 }]);
});

Deno.test("parseLineItems: rejects empty / malformed / non-positive quantity", () => {
  assertEquals(parseLineItems([]), null);
  assertEquals(parseLineItems("nope"), null);
  assertEquals(parseLineItems([{ productId: "p1", quantity: 0 }]), null);
  assertEquals(parseLineItems([{ productId: "p1", quantity: 1.5 }]), null);
  assertEquals(parseLineItems([{ productId: "", quantity: 1 }]), null);
});

Deno.test("create: server-computed amount is persisted; client amount is IGNORED (SoT)", async () => {
  const store = new FakeOrderStore();
  // Client tries to smuggle amount:1 alongside items; create-order never reads it.
  const clientItems = [{ productId: "p1", quantity: 1, amount: 1, price: 1 }];
  const res = await handleCreateOrder(USER, clientItems, {
    orderStore: store,
    priceResolver: fixedResolver(15000),
    generateOrderId: () => "order-abc",
  });
  assertEquals(res.status, 200);
  assertEquals(res.body, { orderId: "order-abc", amount: 15000, orderName: "테스트 상품" });
  // Persisted amount is the SERVER's (numeric string), not the client's 1.
  assertEquals(store.inserted.length, 1);
  assertEquals(store.inserted[0].amount, "15000.00");
  assertEquals(store.inserted[0].user_id, USER);
  assertEquals(store.inserted[0].order_id, "order-abc");
  assertEquals(store.inserted[0].currency, "KRW");
});

Deno.test("create: malformed items -> 400, nothing persisted", async () => {
  const store = new FakeOrderStore();
  const res = await handleCreateOrder(USER, "bad", {
    orderStore: store,
    priceResolver: fixedResolver(15000),
    generateOrderId: () => "order-abc",
  });
  assertEquals(res.status, 400);
  assertEquals(store.inserted.length, 0);
});

Deno.test("create: unpriceable items (resolver null) -> 400, nothing persisted", async () => {
  const store = new FakeOrderStore();
  const res = await handleCreateOrder(USER, [{ productId: "ghost", quantity: 1 }], {
    orderStore: store,
    priceResolver: () => Promise.resolve(null),
    generateOrderId: () => "order-abc",
  });
  assertEquals(res.status, 400);
  assertEquals(store.inserted.length, 0);
});

Deno.test("create: non-positive server price -> 400 (defensive)", async () => {
  const store = new FakeOrderStore();
  const res = await handleCreateOrder(USER, [{ productId: "p1", quantity: 1 }], {
    orderStore: store,
    priceResolver: fixedResolver(0),
    generateOrderId: () => "order-abc",
  });
  assertEquals(res.status, 400);
  assertEquals(store.inserted.length, 0);
});
