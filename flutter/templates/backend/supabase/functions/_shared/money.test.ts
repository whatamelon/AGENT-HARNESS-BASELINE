// _shared/money.test.ts — KRW numeric safety (no float, no fractional won).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { amountsEqual, parseKrwAmount, toNumericString } from "./money.ts";

Deno.test("parseKrwAmount: integer number passes through", () => {
  assertEquals(parseKrwAmount(15000), 15000);
  assertEquals(parseKrwAmount(0), 0);
});

Deno.test("parseKrwAmount: numeric(15,2) string forms normalize to won", () => {
  assertEquals(parseKrwAmount("15000"), 15000);
  assertEquals(parseKrwAmount("15000.00"), 15000);
  assertEquals(parseKrwAmount("15000.0"), 15000);
  assertEquals(parseKrwAmount(" 15000.00 "), 15000); // trimmed
});

Deno.test("parseKrwAmount: fractional won rejected (no sub-won precision)", () => {
  assertEquals(parseKrwAmount(150.5), null);   // non-integer number
  assertEquals(parseKrwAmount("150.5"), null); // non-zero minor units
  assertEquals(parseKrwAmount("150.01"), null);
});

Deno.test("parseKrwAmount: invalid inputs rejected", () => {
  assertEquals(parseKrwAmount(-1), null);
  assertEquals(parseKrwAmount("-1"), null);
  assertEquals(parseKrwAmount("abc"), null);
  assertEquals(parseKrwAmount(NaN), null);
  assertEquals(parseKrwAmount(Infinity), null);
  assertEquals(parseKrwAmount(null), null);
  assertEquals(parseKrwAmount(undefined), null);
  assertEquals(parseKrwAmount({}), null);
});

Deno.test("amountsEqual: number vs numeric-string compare equal", () => {
  assert(amountsEqual(15000, "15000.00"));
  assert(amountsEqual("15000", 15000));
  assert(amountsEqual(15000, 15000));
});

Deno.test("amountsEqual: mismatched amounts are NOT equal (tamper block)", () => {
  assert(!amountsEqual(15000, 15001));
  assert(!amountsEqual(15000, "14999.00"));
});

Deno.test("amountsEqual: unparseable operand fails closed (not equal)", () => {
  assert(!amountsEqual(15000, "abc"));
  assert(!amountsEqual("150.5", 150)); // fractional left side fails to parse
});

Deno.test("toNumericString: produces numeric(15,2) string", () => {
  assertEquals(toNumericString(15000), "15000.00");
  assertEquals(toNumericString(0), "0.00");
});
