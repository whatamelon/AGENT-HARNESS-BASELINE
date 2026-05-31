// _shared/phone.test.ts — Deno test suite for KR phone normalization/allowlist.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isAllowed, isValidKrMobile, normalizeKrPhone, parseAllowlist } from "./phone.ts";

Deno.test("normalizeKrPhone: domestic and international forms -> E.164", () => {
  const expected = "+821012345678";
  assertEquals(normalizeKrPhone("010-1234-5678"), expected);
  assertEquals(normalizeKrPhone("01012345678"), expected);
  assertEquals(normalizeKrPhone("+82 10 1234 5678"), expected);
  assertEquals(normalizeKrPhone("+821012345678"), expected);
  assertEquals(normalizeKrPhone("8210 1234 5678"), expected);
  assertEquals(normalizeKrPhone("008210 1234 5678"), expected);
  assertEquals(normalizeKrPhone(" (010) 1234.5678 "), expected);
});

Deno.test("normalizeKrPhone: rejects non-mobile / garbage", () => {
  assertEquals(normalizeKrPhone(""), null);
  assertEquals(normalizeKrPhone("02-123-4567"), null);  // landline (national starts 2, not 10)
  assertEquals(normalizeKrPhone("011-123-4567"), null); // legacy non-010 -> national starts 11
  assertEquals(normalizeKrPhone("abc"), null);
  assertEquals(normalizeKrPhone("+1 415 555 0100"), null); // US number
});

Deno.test("isValidKrMobile: strict +8210 + 8 digits", () => {
  assert(isValidKrMobile("010-1234-5678"));
  assert(isValidKrMobile("+821012345678"));
  assert(!isValidKrMobile("+82101234567"));   // 7 trailing digits
  assert(!isValidKrMobile("+8210123456789")); // 9 trailing digits
  assert(!isValidKrMobile("+14155550100"));   // foreign rejected
  assert(!isValidKrMobile("011-1234-5678"));  // non-010 prefix
});

Deno.test("parseAllowlist + isAllowed: empty = open mode", () => {
  const empty = parseAllowlist("");
  assertEquals(empty.size, 0);
  assert(isAllowed("+821012345678", empty)); // open mode allows all
});

Deno.test("parseAllowlist + isAllowed: gates to listed numbers", () => {
  const list = parseAllowlist("010-1234-5678, +82 10 9999 0000");
  assertEquals(list.size, 2);
  assert(isAllowed("+821012345678", list));
  assert(isAllowed("+821099990000", list));
  assert(!isAllowed("+821000000001", list)); // not on list -> blocked
});

Deno.test("parseAllowlist: drops unparseable entries", () => {
  const list = parseAllowlist("010-1234-5678, garbage, +1 415 555 0100");
  assertEquals(list.size, 1); // only the KR mobile survives
  assert(list.has("+821012345678"));
});
