// _shared/toss_client.ts
//
// Thin client for the two Toss Payments endpoints the gate needs:
//
//   confirmPayment -> POST https://api.tosspayments.com/v1/payments/confirm
//   getPayment     -> GET  https://api.tosspayments.com/v1/payments/{paymentKey}
//
// AUTH (verified against the Toss API guide):
//   - Basic auth: `Authorization: Basic base64('{SECRET_KEY}:')` (secret key
//     followed by a colon, then base64). The SECRET KEY is a server-only secret
//     (Edge env `TOSS_SECRET_KEY`) — H-4: never in code or README as a real value.
//   - Idempotency: confirm sends `Idempotency-Key: <orderId>` so a retried
//     confirm for the same order is processed once by Toss (network-retry safe).
//
// WEBHOOK AUTHENTICITY (decision — see README-payments.md):
//   The PAYMENT_STATUS_CHANGED webhook body carries NO signature/secret header,
//   so it cannot be authenticated on its own. The webhook handler therefore
//   NEVER trusts the webhook body for state; it calls `getPayment` and treats
//   the Toss API response (Basic-authed) as the authoritative status. `getPayment`
//   is the authenticity mechanism.
//
// The HTTP transport is injected (`FetchLike`) so the pure result-mapping logic
// is unit-testable off the Edge runtime with a fake fetch (no live Toss calls).

/** Minimal structural view of `fetch` (so tests can inject a fake). */
export type FetchLike = (
  url: string,
  init: {
    method: string;
    headers: Record<string, string>;
    body?: string;
  },
) => Promise<{
  status: number;
  // Toss returns JSON for both success and error envelopes.
  json: () => Promise<unknown>;
}>;

/** Normalized payment view extracted from a Toss response (success path). */
export interface TossPayment {
  readonly paymentKey: string;
  readonly orderId: string;
  /** Toss payment status, e.g. DONE / CANCELED / ABORTED / WAITING_FOR_DEPOSIT. */
  readonly status: string;
  /** Authoritative charged amount (Toss `totalAmount`). */
  readonly totalAmount: number;
}

/** Discriminated result: a normalized payment, or a normalized error. */
export type TossResult =
  | { ok: true; payment: TossPayment }
  | { ok: false; error: TossError };

/** Normalized Toss error (HTTP status + Toss error code/message when present). */
export interface TossError {
  /** HTTP status from Toss (or 0 on transport failure). */
  readonly httpStatus: number;
  /** Toss machine-readable error code, e.g. NOT_FOUND_PAYMENT_SESSION. */
  readonly code: string;
  readonly message: string;
}

export interface TossClient {
  /**
   * Confirm (authorize) a payment. `amount` MUST be the server-side order
   * amount (§8-A C-2); Toss rejects a mismatch, and we re-check on our side too.
   * `idempotencyKey` should be the orderId so retries collapse to one charge.
   */
  confirmPayment(args: {
    paymentKey: string;
    orderId: string;
    amount: number;
    idempotencyKey: string;
  }): Promise<TossResult>;

  /**
   * Fetch the authoritative current state of a payment by paymentKey. Used by
   * the webhook handler to avoid trusting the (unsigned) webhook body.
   */
  getPayment(paymentKey: string): Promise<TossResult>;
}

const TOSS_API_BASE = "https://api.tosspayments.com";

/** Build the `Basic base64('{secretKey}:')` Authorization header value. */
export function basicAuthHeader(secretKey: string): string {
  if (!secretKey) {
    throw new Error("toss: TOSS_SECRET_KEY must be a non-empty secret");
  }
  // base64 of "secretKey:" — colon with empty password, per the Toss API guide.
  const encoded = btoa(`${secretKey}:`);
  return `Basic ${encoded}`;
}

/** Extract a normalized payment from a parsed Toss JSON body, or null. */
export function extractPayment(body: unknown): TossPayment | null {
  if (typeof body !== "object" || body === null) return null;
  const o = body as Record<string, unknown>;
  const paymentKey = o.paymentKey;
  const orderId = o.orderId;
  const status = o.status;
  const totalAmount = o.totalAmount;
  if (
    typeof paymentKey !== "string" ||
    typeof orderId !== "string" ||
    typeof status !== "string" ||
    typeof totalAmount !== "number"
  ) {
    return null;
  }
  return { paymentKey, orderId, status, totalAmount };
}

/** Extract a normalized error from a parsed Toss JSON body. */
export function extractError(httpStatus: number, body: unknown): TossError {
  if (typeof body === "object" && body !== null) {
    const o = body as Record<string, unknown>;
    const code = typeof o.code === "string" ? o.code : "UNKNOWN";
    const message = typeof o.message === "string" ? o.message : "toss error";
    return { httpStatus, code, message };
  }
  return { httpStatus, code: "UNKNOWN", message: "toss error" };
}

/**
 * Construct a Toss client over an injected fetch and the server-only secret key.
 * Response mapping is delegated to the pure `extractPayment`/`extractError`
 * helpers so behavior is fully exercised by unit tests with a fake fetch.
 */
export function createTossClient(secretKey: string, fetchImpl: FetchLike): TossClient {
  const authHeader = basicAuthHeader(secretKey);

  async function mapResponse(
    res: { status: number; json: () => Promise<unknown> },
  ): Promise<TossResult> {
    let body: unknown;
    try {
      body = await res.json();
    } catch {
      body = null;
    }
    if (res.status >= 200 && res.status < 300) {
      const payment = extractPayment(body);
      if (payment) return { ok: true, payment };
      // 2xx but unparseable shape — treat as an error so we never act blindly.
      return { ok: false, error: { httpStatus: res.status, code: "MALFORMED_RESPONSE", message: "unparseable Toss payment payload" } };
    }
    return { ok: false, error: extractError(res.status, body) };
  }

  return {
    async confirmPayment({ paymentKey, orderId, amount, idempotencyKey }) {
      const res = await fetchImpl(`${TOSS_API_BASE}/v1/payments/confirm`, {
        method: "POST",
        headers: {
          "Authorization": authHeader,
          "Content-Type": "application/json",
          "Idempotency-Key": idempotencyKey,
        },
        body: JSON.stringify({ paymentKey, orderId, amount }),
      });
      return mapResponse(res);
    },

    async getPayment(paymentKey) {
      const res = await fetchImpl(
        `${TOSS_API_BASE}/v1/payments/${encodeURIComponent(paymentKey)}`,
        {
          method: "GET",
          headers: { "Authorization": authHeader },
        },
      );
      return mapResponse(res);
    },
  };
}
