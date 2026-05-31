// _shared/link_code.test.ts — Deno test suite for non-sequential link codes.
//
// Verifies CSPRNG output shape, non-sequentiality / distribution, collision
// resistance, and shape validation + canonicalization.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canonicalizeLinkCode,
  DEFAULT_CODE_LENGTH,
  generateLinkCode,
  isValidLinkCode,
} from "./link_code.ts";

const ALPHABET_RE = /^[0-9A-HJKMNP-TV-Z]+$/; // Crockford base32 (no I,L,O,U)

Deno.test("generateLinkCode: default length, valid alphabet", () => {
  for (let i = 0; i < 2000; i++) {
    const c = generateLinkCode();
    assertEquals(c.length, DEFAULT_CODE_LENGTH);
    assert(ALPHABET_RE.test(c), `unexpected chars: ${c}`);
    // Excluded ambiguous letters must never appear.
    assert(!/[ILOU]/.test(c), `contains excluded char: ${c}`);
  }
});

Deno.test("generateLinkCode: high entropy / non-sequential (no collisions, no counter)", () => {
  const seen = new Set<string>();
  const N = 5000;
  for (let i = 0; i < N; i++) seen.add(generateLinkCode());
  // 50-bit space over 5000 draws → collisions astronomically unlikely.
  assertEquals(seen.size, N, "collision detected in CSPRNG codes");
});

Deno.test("generateLinkCode: per-position symbol distribution is broad (not constant)", () => {
  // Each of the first-char positions should span many distinct symbols across
  // many draws — a sequential/biased generator would cluster.
  const firstChars = new Set<string>();
  for (let i = 0; i < 1000; i++) firstChars.add(generateLinkCode()[0]);
  assert(firstChars.size > 20, `low first-char entropy: ${firstChars.size}/32`);
});

Deno.test("generateLinkCode: respects length bounds, rejects out-of-range", () => {
  assertEquals(generateLinkCode(6).length, 6);
  assertEquals(generateLinkCode(32).length, 32);
  for (const bad of [0, 5, 33, 100, -1, 3.5]) {
    let threw = false;
    try {
      generateLinkCode(bad);
    } catch {
      threw = true;
    }
    assert(threw, `length ${bad} should throw`);
  }
});

Deno.test("isValidLinkCode: accepts well-formed, rejects malformed", () => {
  assert(isValidLinkCode(generateLinkCode()));
  assert(isValidLinkCode("ABCD23")); // 6 chars, valid alphabet
  assert(isValidLinkCode("abcd23")); // lowercase accepted (canonicalized up)
  assert(!isValidLinkCode("")); // empty
  assert(!isValidLinkCode(null));
  assert(!isValidLinkCode(undefined));
  assert(!isValidLinkCode("ABC")); // too short (<6)
  assert(!isValidLinkCode("A".repeat(33))); // too long (>32)
  assert(!isValidLinkCode("ABCDEI")); // I excluded
  assert(!isValidLinkCode("ABCD-1")); // hyphen not in alphabet
  assert(!isValidLinkCode("ABC 23")); // space
  assert(!isValidLinkCode("../../x")); // path-traversal junk
});

Deno.test("canonicalizeLinkCode: trims + uppercases valid, null for invalid", () => {
  assertEquals(canonicalizeLinkCode("  abcd23 "), "ABCD23");
  assertEquals(canonicalizeLinkCode("ABCD23"), "ABCD23");
  assertEquals(canonicalizeLinkCode("abc"), null); // too short
  assertEquals(canonicalizeLinkCode("ABCDEI"), null); // bad char
  assertEquals(canonicalizeLinkCode(null), null);
  assertEquals(canonicalizeLinkCode(""), null);
});
