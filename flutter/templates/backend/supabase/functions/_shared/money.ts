// _shared/money.ts
//
// KRW money handling for the payment gate (§8-A C-2 — amount Source-of-Truth).
//
// SECURITY / CORRECTNESS:
//   - KRW is a zero-decimal currency (no minor unit). The Toss confirm API and
//     `orders.amount` carry whole-won integer values. Floating point is BANNED
//     (db-essentials: amount is `numeric(15,2)`; we treat it as an integer count
//     of won and never introduce binary-float rounding error).
//   - `orders.amount` is stored as `numeric(15,2)` so a row can come back from
//     PostgREST either as a JS number (e.g. 15000) or a string (e.g. "15000.00").
//     `parseKrwAmount` normalizes BOTH into a safe integer won value, rejecting
//     anything that is not a non-negative whole number of won.
//   - `amountsEqual` is the authoritative comparison used to reject a Toss
//     response whose amount differs from the server-side order amount
//     (amount_mismatch / tamper block).

/** Largest amount we will accept (defensive cap; numeric(15,2) holds far more
 * but a single KRW order above this is almost certainly an error/abuse). */
const MAX_KRW = 1_000_000_000_000; // 1조 원

/**
 * Parse an amount that may arrive as a number (15000) or a `numeric(15,2)`
 * string ("15000.00", "15000") into a safe integer count of won.
 *
 * Returns `null` when the input is not a finite, non-negative whole number of
 * won within range. Any fractional won (KRW has no minor unit) is rejected
 * rather than silently rounded, so a tampered "150.5" never becomes 150 or 151.
 */
export function parseKrwAmount(input: unknown): number | null {
  if (typeof input === "number") {
    if (!Number.isFinite(input)) return null;
    if (!Number.isInteger(input)) return null; // no fractional won
    if (input < 0 || input > MAX_KRW) return null;
    return input;
  }
  if (typeof input === "string") {
    const trimmed = input.trim();
    // Accept "15000" or "15000.00"/"15000.0" (numeric(15,2) string form). The
    // fractional part, if present, MUST be all zeros (no sub-won precision).
    const m = /^(\d{1,15})(?:\.(\d+))?$/.exec(trimmed);
    if (!m) return null;
    const fraction = m[2];
    if (fraction !== undefined && /[^0]/.test(fraction)) return null; // non-zero minor units rejected
    const won = Number(m[1]);
    if (!Number.isSafeInteger(won) || won > MAX_KRW) return null;
    return won;
  }
  return null;
}

/**
 * Authoritative equality for two KRW amounts. Both operands are normalized
 * through `parseKrwAmount` first; if either fails to parse, the amounts are
 * treated as NOT equal (fail-closed for the tamper check).
 */
export function amountsEqual(a: unknown, b: unknown): boolean {
  const pa = parseKrwAmount(a);
  const pb = parseKrwAmount(b);
  if (pa === null || pb === null) return false;
  return pa === pb;
}

/** Format a won integer as a numeric(15,2) string for DB writes ("15000.00"). */
export function toNumericString(won: number): string {
  if (!Number.isInteger(won) || won < 0) {
    throw new Error("toNumericString: won must be a non-negative integer");
  }
  return `${won}.00`;
}
