// _shared/order_state.test.ts — transition matrix + Toss status projection.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { canTransition, isOrderStatus, mapTossStatus } from "./order_state.ts";

Deno.test("canTransition: pending may move to confirmed/canceled/failed", () => {
  assert(canTransition("pending", "confirmed"));
  assert(canTransition("pending", "canceled"));
  assert(canTransition("pending", "failed"));
});

Deno.test("canTransition: confirmed->confirmed BLOCKED (idempotency, no double approval)", () => {
  assert(!canTransition("confirmed", "confirmed"));
});

Deno.test("canTransition: confirmed may only move to canceled", () => {
  assert(canTransition("confirmed", "canceled"));
  assert(!canTransition("confirmed", "failed"));
  assert(!canTransition("confirmed", "pending"));
});

Deno.test("canTransition: terminal states cannot move", () => {
  assert(!canTransition("canceled", "confirmed"));
  assert(!canTransition("canceled", "pending"));
  assert(!canTransition("failed", "confirmed"));
  assert(!canTransition("failed", "pending"));
});

Deno.test("mapTossStatus: DONE -> confirmed", () => {
  assertEquals(mapTossStatus("DONE"), "confirmed");
});

Deno.test("mapTossStatus: CANCELED/PARTIAL_CANCELED -> canceled", () => {
  assertEquals(mapTossStatus("CANCELED"), "canceled");
  assertEquals(mapTossStatus("PARTIAL_CANCELED"), "canceled");
});

Deno.test("mapTossStatus: ABORTED/EXPIRED -> failed", () => {
  assertEquals(mapTossStatus("ABORTED"), "failed");
  assertEquals(mapTossStatus("EXPIRED"), "failed");
});

Deno.test("mapTossStatus: READY/IN_PROGRESS/WAITING_FOR_DEPOSIT -> pending", () => {
  assertEquals(mapTossStatus("READY"), "pending");
  assertEquals(mapTossStatus("IN_PROGRESS"), "pending");
  assertEquals(mapTossStatus("WAITING_FOR_DEPOSIT"), "pending");
});

Deno.test("mapTossStatus: unknown status -> null (fail-closed)", () => {
  assertEquals(mapTossStatus("SOMETHING_NEW"), null);
  assertEquals(mapTossStatus(""), null);
});

Deno.test("isOrderStatus: type guard", () => {
  assert(isOrderStatus("pending"));
  assert(isOrderStatus("confirmed"));
  assert(!isOrderStatus("DONE"));
  assert(!isOrderStatus(123));
});
