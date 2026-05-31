// _shared/code.test.ts — Deno test suite for code crypto primitives.
//
// Run (template repo, when deno is installed):  deno test functions/_shared/
//
// Verifies: CSPRNG output shape + distribution, HMAC determinism + pepper
// dependence, and constant-time-equal correctness.

import { assert, assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateCode, hashCode, timingSafeEqual } from "./code.ts";

Deno.test("generateCode: always 6 numeric digits", () => {
  for (let i = 0; i < 2000; i++) {
    const c = generateCode();
    assert(/^\d{6}$/.test(c), `not 6 digits: ${c}`);
  }
});

Deno.test("generateCode: covers full range incl. leading zeros, no constant", () => {
  const seen = new Set<string>();
  let sawLeadingZero = false;
  for (let i = 0; i < 5000; i++) {
    const c = generateCode();
    seen.add(c);
    if (c[0] === "0") sawLeadingZero = true;
  }
  // High distinct count => not a constant / tiny-range PRNG.
  assert(seen.size > 4000, `low entropy: only ${seen.size} distinct`);
  assert(sawLeadingZero, "never produced a leading-zero code (padding broken)");
});

Deno.test("hashCode: deterministic for same (code,pepper)", async () => {
  const a = await hashCode("123456", "pepper-x");
  const b = await hashCode("123456", "pepper-x");
  assertEquals(a, b);
  assertEquals(a.length, 64); // SHA-256 hex
});

Deno.test("hashCode: differs by code and by pepper", async () => {
  const base = await hashCode("123456", "pepper-x");
  assertNotEquals(base, await hashCode("123457", "pepper-x"));
  assertNotEquals(base, await hashCode("123456", "pepper-y"));
});

Deno.test("hashCode: rejects empty pepper", async () => {
  let threw = false;
  try {
    await hashCode("123456", "");
  } catch {
    threw = true;
  }
  assert(threw, "empty pepper must throw");
});

Deno.test("timingSafeEqual: correctness", () => {
  assert(timingSafeEqual("abc123", "abc123"));
  assert(!timingSafeEqual("abc123", "abc124"));
  assert(!timingSafeEqual("abc", "abcd")); // length mismatch
  assert(timingSafeEqual("", ""));
});
