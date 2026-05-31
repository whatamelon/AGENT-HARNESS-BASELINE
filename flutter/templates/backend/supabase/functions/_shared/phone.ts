// _shared/phone.ts
//
// Korean mobile phone normalization, validation, and allowlist gating.
//
// SECURITY (§8-A C-1):
//   - Only KR mobile numbers (010 / +82 10) are accepted. Everything else is
//     rejected before any SMS is dispatched (toll-fraud / international-pumping
//     surface reduction).
//   - An optional allowlist (Edge env `SMS_PHONE_ALLOWLIST`, comma-separated
//     E.164 numbers) gates who may receive codes during staged rollouts. When
//     the allowlist is empty, all valid KR mobiles pass (open mode).
//
// Canonical form produced by `normalizeKrPhone` is E.164: `+8210XXXXXXXX`.

/** Strip spaces, hyphens, dots, and parentheses from raw user input. */
function stripSeparators(raw: string): string {
  return raw.replace(/[\s.\-()]/g, "");
}

/**
 * Normalize a Korean mobile number to E.164 (`+8210XXXXXXXX`).
 *
 * Accepts the common domestic and international spellings:
 *   - `010-1234-5678`, `01012345678`        -> `+821012345678`
 *   - `+82 10 1234 5678`, `+821012345678`   -> `+821012345678`
 *   - `8210...`, `008210...`                -> `+821012345678`
 *
 * Returns `null` if the input cannot be coerced into a KR mobile shape. This
 * function does NOT assert full validity (see `isValidKrMobile`); it only
 * canonicalizes so downstream checks operate on one representation.
 */
export function normalizeKrPhone(raw: string): string | null {
  if (!raw) return null;
  let s = stripSeparators(raw.trim());

  // International access prefix `00` (e.g. 008210...) -> drop, treat rest as intl.
  if (s.startsWith("00")) s = s.slice(2);

  let national: string | null = null;

  if (s.startsWith("+82")) {
    national = s.slice(3);
  } else if (s.startsWith("82") && s.length >= 11) {
    // `82` country code without `+`. Length guard avoids eating a domestic
    // number that merely begins with 82 (KR mobiles always start 010).
    national = s.slice(2);
  } else if (s.startsWith("0")) {
    // Domestic form: leading trunk `0` -> drop for E.164.
    national = s.slice(1);
  } else {
    national = s;
  }

  if (national === null) return null;
  // Must be a pure-digit national number starting with `10` (mobile prefix).
  if (!/^\d+$/.test(national)) return null;
  if (!national.startsWith("10")) return null;

  return `+82${national}`;
}

/**
 * Strict KR mobile validity check on a normalized E.164 number.
 *
 * KR mobile national number is `10` + 8 digits => `+8210` followed by 8 digits
 * (11 national digits total). Rejects `+82 1[1-9]...` legacy/landline prefixes.
 */
export function isValidKrMobile(input: string): boolean {
  const normalized = normalizeKrPhone(input);
  if (normalized === null) return false;
  // +82 10 XXXX XXXX  -> exactly +8210 + 8 digits.
  return /^\+8210\d{8}$/.test(normalized);
}

/**
 * Parse a comma-separated allowlist env string into a Set of E.164 numbers.
 *
 * Each entry is normalized; unparseable entries are dropped. Returns an empty
 * Set for empty/whitespace input, which callers interpret as "open mode".
 */
export function parseAllowlist(envValue: string | undefined | null): Set<string> {
  const out = new Set<string>();
  if (!envValue) return out;
  for (const part of envValue.split(",")) {
    const normalized = normalizeKrPhone(part);
    if (normalized) out.add(normalized);
  }
  return out;
}

/**
 * Allowlist gate. Returns true when the (already-normalized) phone is allowed
 * to receive a code. An empty allowlist means open mode (all valid mobiles).
 */
export function isAllowed(normalizedPhone: string, allowlist: Set<string>): boolean {
  if (allowlist.size === 0) return true;
  return allowlist.has(normalizedPhone);
}
