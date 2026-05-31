// _shared/link_code.ts
//
// Non-sequential link / referral code generation + validation.
//
// SECURITY (§8-A H-3 / referral integrity):
//   - Codes are drawn from a CSPRNG (`crypto.getRandomValues`) ONLY. `Math.random`
//     is NEVER used: a predictable PRNG would let an attacker enumerate or forge
//     other users' referral / share links.
//   - Codes are non-sequential: they carry no embedded counter or timestamp, so
//     possession of one code reveals nothing about any other and the keyspace
//     cannot be walked.
//   - Crockford base32 alphabet (no I/L/O/U) keeps codes human-shareable and
//     unambiguous while staying URL-safe (no escaping needed in `/l/:code`).
//
// Runtime: depends only on the Web Crypto standard, so it is identical on the
// Supabase Edge (Deno) runtime and unit-testable off the edge.

/**
 * Crockford base32 alphabet: digits 0-9 + uppercase letters excluding I, L, O,
 * U (to avoid visual ambiguity with 1/0 and accidental profanity). 32 symbols
 * => exactly 5 bits of entropy per character.
 */
const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const ALPHABET_SET = new Set(ALPHABET.split(""));

/** Default code length. 10 chars × 5 bits = 50 bits of entropy (~1.1e15 space). */
export const DEFAULT_CODE_LENGTH = 10;

/** Allowed length bounds for a stored/queried code (defends against absurd input). */
const MIN_LENGTH = 6;
const MAX_LENGTH = 32;

/**
 * Generate a non-sequential link code of `length` Crockford-base32 characters
 * using a CSPRNG.
 *
 * Each character is chosen by rejection sampling over `crypto.getRandomValues`:
 * a random byte (0-255) is rejected when it falls in the biased tail
 * (>= `limit`, the largest multiple of 32 that fits in a byte = 256) so every
 * symbol is equiprobable — no modulo bias.
 *
 * `Math.random` is intentionally NOT used.
 *
 * @throws if `length` is outside [MIN_LENGTH, MAX_LENGTH].
 */
export function generateLinkCode(length: number = DEFAULT_CODE_LENGTH): string {
  if (!Number.isInteger(length) || length < MIN_LENGTH || length > MAX_LENGTH) {
    throw new Error(
      `generateLinkCode: length must be an integer in [${MIN_LENGTH}, ${MAX_LENGTH}]`,
    );
  }
  const RANGE = ALPHABET.length; // 32
  const MAX_BYTE = 0xff; // 255
  const limit = MAX_BYTE + 1 - ((MAX_BYTE + 1) % RANGE); // 256 (no bias for 32)

  const out: string[] = [];
  const buf = new Uint8Array(1);
  while (out.length < length) {
    crypto.getRandomValues(buf);
    const draw = buf[0];
    if (draw >= limit) continue; // reject biased tail (none for 32, kept for safety)
    out.push(ALPHABET[draw % RANGE]);
  }
  return out.join("");
}

/**
 * Validate that an externally-supplied code is well-formed: correct length
 * bounds and only Crockford-base32 characters. This is a *shape* check used to
 * reject obviously-malformed / injection input before a DB lookup — it does NOT
 * assert the code exists (that is the resolver's job).
 *
 * Input is uppercased first so a user typing a lowercase share code still
 * matches (the stored canonical form is uppercase).
 */
export function isValidLinkCode(code: string | null | undefined): boolean {
  if (!code) return false;
  const upper = code.toUpperCase();
  if (upper.length < MIN_LENGTH || upper.length > MAX_LENGTH) return false;
  for (const ch of upper) {
    if (!ALPHABET_SET.has(ch)) return false;
  }
  return true;
}

/**
 * Canonicalize a code for storage / lookup: trim + uppercase. Returns null when
 * the result is not a valid code shape, so callers get a single guarded value.
 */
export function canonicalizeLinkCode(code: string | null | undefined): string | null {
  if (!code) return null;
  const upper = code.trim().toUpperCase();
  return isValidLinkCode(upper) ? upper : null;
}
