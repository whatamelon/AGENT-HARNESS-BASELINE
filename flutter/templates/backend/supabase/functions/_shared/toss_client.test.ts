// _shared/toss_client.test.ts — confirm/getPayment over a fake fetch.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  basicAuthHeader,
  createTossClient,
  extractError,
  extractPayment,
  type FetchLike,
} from "./toss_client.ts";

const SECRET = "test_sk_xyz";

interface Captured {
  url: string;
  method: string;
  headers: Record<string, string>;
  body?: string;
}

function fakeFetch(
  response: { status: number; body: unknown },
  captured: Captured[],
): FetchLike {
  return (url, init) => {
    captured.push({ url, method: init.method, headers: init.headers, body: init.body });
    return Promise.resolve({
      status: response.status,
      json: () => Promise.resolve(response.body),
    });
  };
}

Deno.test("basicAuthHeader: base64('{secret}:')", () => {
  // btoa("test_sk_xyz:") computed independently.
  assertEquals(basicAuthHeader(SECRET), `Basic ${btoa("test_sk_xyz:")}`);
});

Deno.test("basicAuthHeader: empty secret refused", () => {
  let threw = false;
  try {
    basicAuthHeader("");
  } catch {
    threw = true;
  }
  assert(threw);
});

Deno.test("confirmPayment: posts to /v1/payments/confirm with Basic auth + Idempotency-Key + body", async () => {
  const captured: Captured[] = [];
  const fetchImpl = fakeFetch(
    { status: 200, body: { paymentKey: "pk1", orderId: "o1", status: "DONE", totalAmount: 15000 } },
    captured,
  );
  const client = createTossClient(SECRET, fetchImpl);
  const res = await client.confirmPayment({ paymentKey: "pk1", orderId: "o1", amount: 15000, idempotencyKey: "o1" });

  assert(res.ok);
  if (res.ok) {
    assertEquals(res.payment, { paymentKey: "pk1", orderId: "o1", status: "DONE", totalAmount: 15000 });
  }
  const call = captured[0];
  assertEquals(call.url, "https://api.tosspayments.com/v1/payments/confirm");
  assertEquals(call.method, "POST");
  assertEquals(call.headers["Authorization"], `Basic ${btoa("test_sk_xyz:")}`);
  assertEquals(call.headers["Idempotency-Key"], "o1");
  assertEquals(JSON.parse(call.body ?? "{}"), { paymentKey: "pk1", orderId: "o1", amount: 15000 });
});

Deno.test("confirmPayment: non-2xx -> normalized error", async () => {
  const captured: Captured[] = [];
  const fetchImpl = fakeFetch(
    { status: 400, body: { code: "ALREADY_PROCESSED_PAYMENT", message: "이미 처리된 결제" } },
    captured,
  );
  const client = createTossClient(SECRET, fetchImpl);
  const res = await client.confirmPayment({ paymentKey: "pk1", orderId: "o1", amount: 15000, idempotencyKey: "o1" });
  assert(!res.ok);
  if (!res.ok) {
    assertEquals(res.error.httpStatus, 400);
    assertEquals(res.error.code, "ALREADY_PROCESSED_PAYMENT");
  }
});

Deno.test("confirmPayment: 2xx but malformed payload -> error (never act blindly)", async () => {
  const captured: Captured[] = [];
  const fetchImpl = fakeFetch({ status: 200, body: { unexpected: true } }, captured);
  const client = createTossClient(SECRET, fetchImpl);
  const res = await client.confirmPayment({ paymentKey: "pk1", orderId: "o1", amount: 15000, idempotencyKey: "o1" });
  assert(!res.ok);
  if (!res.ok) assertEquals(res.error.code, "MALFORMED_RESPONSE");
});

Deno.test("getPayment: GET /v1/payments/{paymentKey} with Basic auth (authenticity re-fetch)", async () => {
  const captured: Captured[] = [];
  const fetchImpl = fakeFetch(
    { status: 200, body: { paymentKey: "pk9", orderId: "o9", status: "DONE", totalAmount: 30000 } },
    captured,
  );
  const client = createTossClient(SECRET, fetchImpl);
  const res = await client.getPayment("pk9");
  assert(res.ok);
  if (res.ok) assertEquals(res.payment.orderId, "o9");
  assertEquals(captured[0].url, "https://api.tosspayments.com/v1/payments/pk9");
  assertEquals(captured[0].method, "GET");
  assertEquals(captured[0].headers["Authorization"], `Basic ${btoa("test_sk_xyz:")}`);
});

Deno.test("getPayment: encodes paymentKey in the path", async () => {
  const captured: Captured[] = [];
  const fetchImpl = fakeFetch({ status: 404, body: { code: "NOT_FOUND_PAYMENT", message: "x" } }, captured);
  const client = createTossClient(SECRET, fetchImpl);
  await client.getPayment("pk/with space");
  assertEquals(captured[0].url, "https://api.tosspayments.com/v1/payments/pk%2Fwith%20space");
});

Deno.test("extractPayment / extractError helpers", () => {
  assertEquals(
    extractPayment({ paymentKey: "p", orderId: "o", status: "DONE", totalAmount: 10 }),
    { paymentKey: "p", orderId: "o", status: "DONE", totalAmount: 10 },
  );
  assertEquals(extractPayment({ paymentKey: "p" }), null);
  assertEquals(extractPayment(null), null);
  assertEquals(extractError(500, null), { httpStatus: 500, code: "UNKNOWN", message: "toss error" });
});
