// _shared/code.ts
//
// Verification-code cryptography primitives for the self-hosted SMS auth gate.
//
// SECURITY (§8-A C-1):
//   - generateCode: 6-digit code from a CSPRNG ONLY. `Math.random` is never used.
//   - hashCode:     HMAC-SHA256(code, pepper). The plaintext code is NEVER persisted;
//                   only the HMAC digest is stored (H-6 server-only write).
//   - timingSafeEqual: constant-time comparison to defend against timing side-channels.
//
// Runtime: depends only on the Web Crypto standard (`crypto.getRandomValues`,
// `crypto.subtle`). Identical on the Supabase Edge (Deno) runtime and on
// bun/node, which is why these pure functions are unit-testable off the edge.

/**
 * Generate a zero-padded 6-digit numeric verification code using a CSPRNG.
 *
 * Uses rejection sampling over `crypto.getRandomValues` to avoid modulo bias:
 * a uint32 has 2^32 values; the largest multiple of 1_000_000 that fits is
 * `limit`. Any draw at or above `limit` is rejected and re-drawn so every
 * 6-digit value is equiprobable.
 *
 * `Math.random` is intentionally NOT used (predictable PRNG => guessable codes).
 */
export function generateCode(): string {
  const RANGE = 1_000_000; // 000000..999999
  const MAX_UINT32 = 0xffffffff; // 4_294_967_295
  // Largest multiple of RANGE that fits in a uint32; rejection threshold.
  const limit = MAX_UINT32 - (MAX_UINT32 % RANGE);

  const buf = new Uint32Array(1);
  let draw: number;
  do {
    crypto.getRandomValues(buf);
    draw = buf[0];
  } while (draw >= limit);

  const n = draw % RANGE;
  return n.toString().padStart(6, "0");
}

/** Encode a UTF-8 string to bytes.
 *
 * Return type is pinned to `Uint8Array<ArrayBuffer>` (not the looser
 * `Uint8Array<ArrayBufferLike>`) so the bytes satisfy Web Crypto's
 * `BufferSource` parameter under strict lib typings — `TextEncoder.encode`
 * always allocates a fresh plain `ArrayBuffer`. */
function utf8(input: string): Uint8Array<ArrayBuffer> {
  return new TextEncoder().encode(input) as Uint8Array<ArrayBuffer>;
}

/** Lowercase hex-encode a byte buffer. */
function toHex(bytes: ArrayBuffer): string {
  const view = new Uint8Array(bytes);
  let out = "";
  for (let i = 0; i < view.length; i++) {
    out += view[i].toString(16).padStart(2, "0");
  }
  return out;
}

/**
 * HMAC-SHA256(code, pepper) -> lowercase hex digest.
 *
 * The `pepper` is a server-only secret (Edge env `SMS_CODE_PEPPER`). Hashing
 * with a keyed MAC (rather than a bare hash) means a DB leak of `code_hash`
 * does not let an attacker brute-force the 6-digit space offline without the
 * pepper, and the per-row TTL keeps the online window tiny.
 *
 * @throws if `pepper` is empty (refuse to hash with an absent secret).
 */
export async function hashCode(code: string, pepper: string): Promise<string> {
  if (!pepper) {
    throw new Error("hashCode: pepper (SMS_CODE_PEPPER) must be a non-empty secret");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    utf8(pepper),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, utf8(code));
  return toHex(sig);
}

/**
 * Constant-time string comparison.
 *
 * Returns false immediately on length mismatch (length is not secret here —
 * both operands are fixed-width hex digests). For equal lengths every byte is
 * XOR-accumulated so total work is independent of where the first difference
 * occurs, preventing early-exit timing leaks.
 */
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}
