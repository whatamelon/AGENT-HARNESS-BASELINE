# Payments — Toss Payments gate (Supabase backend template)

Reusable **template** for a server-authoritative Toss Payments flow on Supabase
(Edge Functions + Postgres): create order → confirm → webhook. This directory is
a *template*, not a live project: a consumer (e.g. `yipark`) copies the migration
+ functions into its own tree, wires the price resolver, and deploys with its own
secrets.

This is **Lane B** of the Flutter harness P5 (server: payments). It implements
the §8-A **C-2** payment gate — amount Source-of-Truth, idempotency, and webhook
authenticity verification — plus the `orders` / `payment_events` schema + RLS.

> **Honesty boundary**: the harness has **no live Toss account, no Supabase, and
> no real PG runtime**. The code here is complete + unit-tested (pure logic) +
> type-checked (`deno check`). It is **not** deployed, charged, or runtime-proven.
> Live PG (real `paymentKey`s, real charges, real webhooks, store review) happens
> in the consumer repo (yipark). Do not read any claim here as "paid" or
> "deployed in production".

---

## Flow (why three endpoints)

```
  Client (Flutter)                    Edge Functions (Deno)            Toss
  ────────────────                    ─────────────────────           ────
  1. choose items  ──items──────────▶ payment-create-order
                                        · server PRICES the items      (no Toss call)
                                        · INSERT orders(status=pending,
                                          amount=SERVER amount)
                   ◀─{orderId,amount}─
  2. Toss widget   ──orderId,amount──────────────────────────────────▶ pay
                   ◀──────────────────────────────── paymentKey ───────
  3. confirm       ──{orderId,        payment-confirm
                       paymentKey}──▶   · amount = orders.amount (DB SoT)
                       (NO amount)      · POST /v1/payments/confirm
                                          {paymentKey, orderId, amount}  ─▶ confirm
                                          Idempotency-Key: orderId       ◀─ {status,totalAmount}
                                        · reject if totalAmount != DB amount
                                        · atomic pending→confirmed
                   ◀─{status:confirmed}─
  async (deposit / cancel)            payment-webhook  ◀──── POST (UNSIGNED body) ─── Toss
                                        · re-fetch GET /v1/payments/{paymentKey} ─▶
                                          (authoritative state)                  ◀─ {status,...}
                                        · dedupe on event_id
                                        · apply AUTHORITATIVE status
```

---

## Toss API facts used (verified against the Toss API guide)

| Call | Endpoint | Auth | Notes |
|------|----------|------|-------|
| Confirm | `POST https://api.tosspayments.com/v1/payments/confirm` | `Authorization: Basic base64('{SECRET_KEY}:')` | Body `{paymentKey, orderId, amount}`. Idempotent via `Idempotency-Key` header (we send the `orderId`). Success status `DONE`. |
| Get payment | `GET https://api.tosspayments.com/v1/payments/{paymentKey}` | same Basic auth | Returns authoritative `status`, `orderId`, `totalAmount`. Used to verify webhook authenticity. |
| Webhook | `POST` to your endpoint | none | `PAYMENT_STATUS_CHANGED` body has **no signature header** — see below. |

One-time payment status enum (from the webhook / get-payment docs):
`READY, IN_PROGRESS, WAITING_FOR_DEPOSIT, DONE, EXPIRED, ABORTED, CANCELED,
PARTIAL_CANCELED`. We project these onto our internal order status in
`_shared/order_state.ts` (`DONE→confirmed`, `CANCELED/PARTIAL_CANCELED→canceled`,
`ABORTED/EXPIRED→failed`, the rest stay `pending`).

### Webhook authenticity — adopted method: **re-fetch (option b)**

The `PAYMENT_STATUS_CHANGED` webhook carries **no signature/secret header** —
only the virtual-account `DEPOSIT_CALLBACK` event includes a `secret` token. A
signature-header strategy is therefore **not** available for the general payment
webhook. We adopt the safer, universal option: **never trust the webhook body**.
The handler extracts only the `paymentKey` from the (untrusted) body, then calls
`GET /v1/payments/{paymentKey}` (Basic-authed with the server secret) and treats
the **Toss API response as the authoritative status**. A forged body whose
`paymentKey` does not resolve at Toss returns `401` and changes nothing.

---

## §8-A C-2 mapping (where each guarantee lives)

| Guarantee | Where |
|-----------|-------|
| **Amount SoT** — client never supplies the amount | `payment-create-order/core.ts` computes the amount via the injected `PriceResolver` and persists `orders.amount` (server-only write). `payment-confirm/core.ts` reads the amount **from the DB** and sends THAT to Toss; never from the client body. |
| **Amount tamper block** | `payment-confirm/core.ts` compares the Toss response `totalAmount` against the DB amount via `money.ts::amountsEqual`; a mismatch → `409 amount_mismatch`, no state change. |
| **Idempotency — confirm** | `Idempotency-Key: orderId` on the Toss call **and** a conditional `pending→confirmed` transition (`orders.order_id` UNIQUE + `WHERE status='pending'`). A duplicate confirm changes 0 rows → `already_confirmed` (no double approval). |
| **Idempotency — webhook** | `payment_events.event_id` UNIQUE (`paymentKey:authoritativeStatus`); a repeat delivery is a no-op `200 ignored`. |
| **Webhook authenticity** | `payment-webhook/core.ts` re-fetches via `toss_client.ts::getPayment` and acts on the authoritative status only. |
| **State machine** | `_shared/order_state.ts` permits only `pending→{confirmed,canceled,failed}` and `confirmed→canceled`; `confirmed→confirmed` is blocked. |
| **Money safety** | `_shared/money.ts` — KRW integer won, `numeric(15,2)` string/number normalization, no float, fractional won rejected. |

---

## Secrets / env (H-4 — Edge env ONLY, never in code/README)

These are read at runtime via `Deno.env.get(...)` in the `index.ts` shells and
must be set on the Edge function environment. **No real values appear in this
repo.**

| Env var | Used by | Notes |
|---------|---------|-------|
| `SUPABASE_URL` | all | project URL |
| `SUPABASE_ANON_KEY` | create-order, confirm | validates the caller JWT (`auth.getUser`) |
| `SUPABASE_SERVICE_ROLE_KEY` | all | server-only writes to `orders` / `payment_events` (RLS bypass). **Secret.** |
| `TOSS_SECRET_KEY` | confirm, webhook | Toss Basic-auth secret key. **Secret.** Never logged; only base64-encoded into the `Authorization` header. |

```bash
supabase secrets set \
  TOSS_SECRET_KEY=<your-toss-secret> \
  SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
# SUPABASE_URL / SUPABASE_ANON_KEY are provided by the platform.
```

---

## RLS (migration `*_payments.sql`)

- `orders`: clients may **read their own** rows (`user_id = auth.uid()`). There is
  **no** client insert/update/delete policy — every write to `amount` / `status`
  / `payment_key` is done by the service-role client, which bypasses RLS. A
  client therefore cannot create or alter an amount or move an order's status.
- `payment_events`: **service-role only** (no client policy).
- `orders.amount` is `numeric(15,2) CHECK (amount > 0)` (no float).
- DDL-only: the migration ships **no seed/demo data**.

### yipark integration notes

1. Place `migrations/*_payments.sql` under `supabase/migrations/` with a fresh
   timestamp; apply via `npm run db:migrate`. If a `users`/`profiles` table
   already exists, keep `orders.user_id → auth.users(id)` as-is.
2. Wire the price resolver in `payment-create-order/index.ts` (`resolvePrice`):
   look each `productId` up in your **server-trusted** `products` table and sum
   `price × quantity`. **Never** accept a client-supplied price. The template
   ships a `throw` placeholder on purpose so an unwired deploy fails loudly
   rather than charging a guessed amount.
3. Deploy:
   ```bash
   supabase functions deploy payment-create-order
   supabase functions deploy payment-confirm
   supabase functions deploy payment-webhook --no-verify-jwt
   ```
   (`payment-webhook` is public — Toss is unauthenticated — but its security comes
   from the `getPayment` re-fetch + `event_id` idempotency, not from the request.)
4. Register the webhook URL in the Toss dashboard for `PAYMENT_STATUS_CHANGED`
   (and `DEPOSIT_CALLBACK` if you use virtual accounts; the same re-fetch path
   covers it via `paymentKey`).

---

## Tests (deno, pure logic — no live Toss/Supabase)

```bash
deno check functions/payment-*/*.ts \
  functions/_shared/{toss_client,money,order_state,payment_store,payment_audit}.ts
deno test functions/
```

Coverage highlights:
- **create-order**: server-computed amount persisted; a client-smuggled `amount`
  is ignored; malformed / unpriceable input rejected (nothing persisted).
- **confirm**: DB amount is what reaches Toss (no client amount param exists);
  Toss `totalAmount` mismatch → `amount_mismatch`; re-confirm and concurrent
  winner → `already_confirmed` (no double approval); non-pending / other-user /
  not-found / Toss-error / unexpected-status paths.
- **webhook**: authoritative re-fetch drives state (a lying body is overridden);
  unverifiable `paymentKey` → `401` with no state change; duplicate `event_id` →
  `ignored`; still-pending authoritative status records but does not transition.
- **order_state / money / toss_client**: transition matrix, numeric safety,
  Basic-auth header + Idempotency-Key + path encoding.
