// link-resolve/core.test.ts — Deno test suite for the installed-app resolver.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleResolve, type ResolveDeps } from "./core.ts";
import type { LinkRecord, LinkStore } from "../_shared/link_store.ts";

function fakeStore(rows: Record<string, LinkRecord>): LinkStore {
  return { findByCode: (code) => Promise.resolve(rows[code] ?? null) };
}

function deps(overrides: Partial<ResolveDeps> = {}): ResolveDeps {
  return { store: fakeStore({}), homeRoute: "/", ...overrides };
}

Deno.test("resolve: known code → stored route + referralCode", async () => {
  const code = "ABCD23WXYZ";
  const store = fakeStore({
    [code]: { route: "/onyu/referral/accept", referralCode: "REF123", expiresAt: null },
  });
  const r = await handleResolve(code, deps({ store }));
  assertEquals(r.status, 200);
  assertEquals(r.body, { route: "/onyu/referral/accept", referralCode: "REF123" });
});

Deno.test("resolve: known code without referral → route only", async () => {
  const code = "ABCD23WXYZ";
  const store = fakeStore({ [code]: { route: "/park/contract", referralCode: null, expiresAt: null } });
  const r = await handleResolve(code, deps({ store }));
  assertEquals(r.body, { route: "/park/contract" });
});

Deno.test("resolve: lowercase code is canonicalized and matches", async () => {
  const code = "ABCD23WXYZ";
  const store = fakeStore({ [code]: { route: "/x", referralCode: null, expiresAt: null } });
  const r = await handleResolve("abcd23wxyz", deps({ store }));
  assertEquals(r.body.route, "/x");
});

Deno.test("resolve: unknown code → home route fallback", async () => {
  const r = await handleResolve("UNKNOWNXYZ", deps({ homeRoute: "/" }));
  assertEquals(r.body, { route: "/" });
});

Deno.test("resolve: malformed / null code → home route", async () => {
  assertEquals((await handleResolve(null, deps())).body, { route: "/" });
  assertEquals((await handleResolve("../etc/passwd", deps())).body, { route: "/" });
  assertEquals((await handleResolve("AB", deps())).body, { route: "/" }); // too short
});

Deno.test("resolve: expired code → home route", async () => {
  const code = "ABCD23WXYZ";
  const store = fakeStore({
    [code]: { route: "/onyu/referral", referralCode: "R", expiresAt: "2020-01-01T00:00:00Z" },
  });
  const r = await handleResolve(code, deps({ store, now: () => new Date("2026-01-01T00:00:00Z") }));
  assertEquals(r.body, { route: "/" });
});

Deno.test("resolve: route-injection — stored unsafe route is dropped to home (fail safe)", async () => {
  const code = "ABCD23WXYZ";
  // A row whose route somehow fails the safe-route gate must NOT be returned.
  const store = fakeStore({
    [code]: { route: "//evil.com", referralCode: null, expiresAt: null },
  });
  const r = await handleResolve(code, deps({ store, homeRoute: "/" }));
  assertEquals(r.body, { route: "/" });
});

Deno.test("resolve: request code is never echoed as a route", async () => {
  // The code itself is a lookup key only; a code that looks like a path must
  // never become the returned route.
  const r = await handleResolve("ABCD23WXYZ", deps({ homeRoute: "/home" }));
  assertEquals(r.body.route, "/home");
});

Deno.test("resolve: misconfigured homeRoute throws", async () => {
  let threw = false;
  try {
    await handleResolve("X", deps({ homeRoute: "https://evil.com" }));
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
