# Self-hosted SMS verification — Supabase backend template

Reusable **template** for a self-hosted phone-number verification flow on
Supabase (Edge Functions + Postgres). This directory is a *template*, not a live
project: a consumer (e.g. `yipark`) copies the migration + functions into its own
`supabase/` tree and deploys them.

This is **Lane B** of the Flutter harness P3 work. It is where the §8-A server
security gates (C-1 anti-abuse, H-4 secrets-in-env, H-6 server-only verified
write) live. The Flutter client (Lane A) calls these two endpoints.

> Honesty boundary: the harness has **no live Supabase**. The code here is
> complete + unit-tested (pure logic) + type-checked. It is **not** deployed or
> runtime-proven against a live project — that happens in the consumer repo.

---

## Layout

```
supabase/
├── migrations/<ts>_sms_verification.sql   # tables, RLS, atomic RPCs (DDL-only)
└── functions/
    ├── _shared/
    │   ├── code.ts          # CSPRNG 6-digit, HMAC-SHA256(code,pepper), constant-time compare
    │   ├── phone.ts         # KR +82/010 normalize + validate + allowlist
    │   ├── rate_limit.ts    # multi-layer limiter (phone 5m/1h/24h + IP + global breaker)
    │   ├── sms_gateway.ts   # SmsGateway interface + Solapi/Aligo adapters (env keys)
    │   ├── store.ts         # service-role persistence (verifications + rate events)
    │   ├── audit.ts         # masked audit logging
    │   └── *.test.ts        # Deno test suites (pure logic)
    ├── sms-request-code/{index.ts, core.ts, core.test.ts}
    └── sms-verify-code/{index.ts, core.ts, core.test.ts}
```

`core.ts` holds the pure, dependency-injected business logic (unit-tested with
in-memory fakes). `index.ts` is the thin Deno `serve` shell (env, IP, JWT, build
service-role client, delegate to core).

---

## Endpoints (shared contract)

### `POST /functions/v1/sms-request-code`

**Requires auth** (deploy with JWT verification ON). The flow is social-login
first, then phone verification, so a Supabase session already exists. The caller
must present `Authorization: Bearer <supabase-jwt>`; the issued code is bound to
*that* user (`requested_by`) and can only be redeemed by the same user — this is
the number-takeover block (HIGH fix). Abuse is bounded by both JWT and rate
limits.

Request:
```json
{ "phone": "010-1234-5678" }
```

Responses:
| Case | Status | Body |
|------|--------|------|
| Accepted (or suppressed — see anti-enumeration) | `200` | `{ "ok": true, "ttlSeconds": 180 }` |
| Missing/invalid JWT | `401` | `{ "ok": false, "reason": "unauthenticated" }` |
| Rate limited | `429` | `{ "ok": false, "retryAfter": <seconds> }` |

**Anti-enumeration (defense-in-depth)**: an invalid KR mobile, or a number not
on the allowlist, returns the *same* `200 { ok: true, ttlSeconds: 180 }` as a
real send but dispatches nothing. Only a rate-limit breach returns `429`. Even an
authenticated caller cannot distinguish "valid + sent" from "invalid / not
allowed". Because the endpoint now requires auth, an unauthenticated party can no
longer drive the SMS sender or probe numbers at all.

### `POST /functions/v1/sms-verify-code`

**Requires auth** (deploy with JWT verification ON). The caller must present
`Authorization: Bearer <supabase-jwt>`; the verified phone is bound to *that*
user's profile.

Request:
```json
{ "phone": "010-1234-5678", "code": "123456" }
```

Responses:
| Case | Status | Body |
|------|--------|------|
| Verified | `200` | `{ "verified": true }` |
| Wrong / expired / locked out | `400` | `{ "verified": false, "reason": "invalid" \| "expired" \| "too_many_attempts" }` |
| Missing/invalid JWT | `401` | `{ "verified": false, "reason": "unauthenticated" }` |

---

## §8-A C-1 security gate — where each control lives

| Control | Location |
|---------|----------|
| **CSPRNG 6-digit code** (no `Math.random`) | `_shared/code.ts` `generateCode()` — `crypto.getRandomValues` + rejection sampling (no modulo bias) |
| **HMAC-SHA256(code, pepper), hash-only storage** | `_shared/code.ts` `hashCode()`; persisted by `store.ts insert()`; plaintext never stored |
| **Constant-time compare** | `_shared/code.ts` `timingSafeEqual()`; used in `sms-verify-code/core.ts` |
| **TTL 180s, single-use** | `sms-request-code/core.ts` `CODE_TTL_SECONDS`; `expires_at` check + `consume()` in verify core |
| **Single active code per phone** | `sms-request-code/core.ts` calls `invalidateOutstanding()` before insert |
| **Per-code 5-attempt cap** | `MAX_ATTEMPTS=5`; atomic `incrementAttempts()` (RPC `increment_sms_attempt`) BEFORE compare; lockout burns the code |
| **Multi-layer rate limit** (atomic, toll-fraud) | `_shared/rate_limit.ts`: phone 1/5min, 3/1h, 5/24h + IP/24h + global 60/min circuit breaker; `enforce()` in request core. Counting is **atomic** per key via `record_rate_event`'s `pg_advisory_xact_lock` (CRITICAL fix — concurrent same-key requests cannot race past the cap) |
| **Uniform response (enumeration block)** | `sms-request-code/core.ts` — invalid/not-allowed/gateway-fail all return identical `200` |
| **KR +82/010 allowlist** | `_shared/phone.ts` `isValidKrMobile` + `parseAllowlist`/`isAllowed`; gate in request core |
| **AuthN on BOTH endpoints** | `sms-request-code/index.ts` + `sms-verify-code/index.ts` — JWT required, `auth.getUser()` resolves userId |
| **Code↔requester binding** (takeover block, HIGH fix) | `requested_by` set on request (`core.ts`); verify rejects a mismatch as `invalid` without touching the owner's attempt counter (`sms-verify-code/core.ts`) |
| **One verified phone per account** (HIGH fix) | `uq_profiles_phone_verified` partial unique index; `markPhoneVerified()` returns `false` on conflict → verify yields `invalid` |
| **H-6 server-only verified write** | `markPhoneVerified()` uses service-role client; RLS + trigger block client writes (see migration) |
| **H-4 secrets in env only** | all keys via `Deno.env.get(...)`; zero literals in code/README |
| **Masked audit on every branch** | `_shared/audit.ts` — phone/IP masked, code never logged |

---

## Migration RLS summary

- `sms_verifications`: RLS enabled, **no client policy** → only the service-role
  (which bypasses RLS) can read/write. Codes are never exposed to clients. Each
  row carries `requested_by` (FK → `auth.users`) binding the code to the
  authenticated requester (takeover block).
- `sms_rate_events`: RLS enabled, **no client policy** → server-only ledger.
- `profiles`:
  - `profiles_authenticated_select_own` — a user may **READ** their own row
    (including `phone_verified`).
  - `profiles_authenticated_update_own` — a user may UPDATE their own row, but a
    `before update` trigger (`guard_phone_verified_columns`) **rejects** any
    client change to `phone_verified` / `phone_verified_at`. Only the
    service-role may set them (H-6).
  - `uq_profiles_phone_verified` — partial unique index on `phone` **WHERE
    phone_verified**: a number may be verified on at most one profile. A hijack
    attempt fails at the DB even if app-layer checks regress (HIGH fix).
- RPCs (`increment_sms_attempt`, `record_rate_event`, `count_rate_events`,
  `prune_sms_data`) are `SECURITY DEFINER` with `EXECUTE` **revoked** from
  `anon`/`authenticated` and granted only to `service_role`.

The `profiles` block uses `create table if not exists` + idempotent
`alter table ... add column if not exists` so it works standalone in the template
**and** when `yipark` already has a `profiles` table. For yipark: drop the
`create table` block and keep only the column adds against the real table.

---

## Deploy (consumer repo, e.g. yipark)

1. Copy `migrations/<ts>_sms_verification.sql` into your `supabase/migrations/`
   with a fresh timestamp (must be greater than your latest). Adapt the
   `profiles` block to your real table.
2. Copy `functions/_shared`, `functions/sms-request-code`, `functions/sms-verify-code`
   into your `supabase/functions/`.
3. Apply the migration via your project workflow (`npm run db:migrate` /
   `supabase db push`). Do **not** apply DDL via Supabase MCP.
4. Set Edge function secrets (see env table), then deploy:
   ```bash
   supabase functions deploy sms-request-code       # JWT verification ON (HIGH fix)
   supabase functions deploy sms-verify-code        # JWT verification ON
   ```
5. Schedule `select prune_sms_data();` (e.g. pg_cron / scheduled function) to
   garbage-collect expired codes and old rate events.

---

## Required environment (Edge function secrets — values NEVER in code)

| Env var | Purpose |
|---------|---------|
| `SUPABASE_URL` | Project URL (Supabase-provided) |
| `SUPABASE_ANON_KEY` | Anon key — used only to validate the caller's JWT in `sms-verify-code` |
| `SUPABASE_SERVICE_ROLE_KEY` | Service-role key — server-only writes (H-6). Never ship to the client. |
| `SMS_CODE_PEPPER` | Secret pepper for HMAC. Rotate carefully (invalidates in-flight codes). High-entropy random string. |
| `SMS_PROVIDER` | `solapi` \| `aligo` \| `noop` |
| `SMS_ALLOW_NOOP` | `1` to permit the no-op gateway (dev only). Leave unset in prod. |
| `SMS_SENDER_NUMBER` | Registered, pre-approved sender number |
| `SMS_PHONE_ALLOWLIST` | Comma-separated E.164/KR numbers. Empty = open mode (all valid KR mobiles). |
| `SOLAPI_API_KEY` / `SOLAPI_API_SECRET` | Solapi credentials (if `SMS_PROVIDER=solapi`) |
| `ALIGO_API_KEY` / `ALIGO_USER_ID` | Aligo credentials (if `SMS_PROVIDER=aligo`) |

Set them with:
```bash
supabase secrets set SMS_CODE_PEPPER=... SMS_PROVIDER=solapi SOLAPI_API_KEY=... # etc.
```

> **AlimTalk preferred**: for production, switch the gateway adapter to a
> KakaoTalk 알림톡 template (`type: "ATA"` + `templateId` for Solapi; the
> `/alimtalk/send/` endpoint for Aligo). Higher deliverability, pre-approved
> template avoids per-message content review. SMS is the documented fallback.

---

## Tests

Pure-logic suites ship as Deno tests (`*.test.ts`, importing
`https://deno.land/std@0.224.0/...`). When `deno` is installed:

```bash
cd supabase
deno check functions/**/*.ts
deno test functions/_shared/ functions/sms-request-code/ functions/sms-verify-code/
```

The suites cover: CSPRNG shape/distribution + `Math.random` absence, HMAC
determinism/pepper-dependence, constant-time compare, KR phone
normalize/validate/allowlist, multi-layer rate-limit decisions, audit masking,
and both handler cores (uniform response, anti-enumeration, rate-limit 429,
TTL/expiry, attempt-cap lockout, server-only verified write, code↔requester
binding / takeover rejection, and one-verified-phone-per-account conflict).

### Live verification (deferred to consumer)

Two correctness properties are enforced in **SQL** and therefore cannot be
exercised by the Deno suites (the harness has no live Postgres):

1. **Rate-limit atomicity** — `record_rate_event` serializes concurrent same-key
   inserts with `pg_advisory_xact_lock`. The Deno test
   (`rate_limit.test.ts` → "decide models atomic distinct counts…") asserts the
   *decision* logic given the atomic-count contract; the atomicity of the lock
   itself must be confirmed with a **concurrency test against a live Postgres**
   in the consumer (e.g. yipark): fire N parallel `record_rate_event(key, w)`
   and assert the returned counts are exactly `1..N` (no duplicates), and that
   only the first request within a `max:1` window is admitted.
2. **One verified phone per account** — `uq_profiles_phone_verified` is a DB
   constraint; a live insert/update conflict (SQLSTATE `23505`) must be observed
   against a real `profiles` table to confirm `markPhoneVerified()` returns
   `false` (mapped to `invalid`).

> Honesty boundary: the pure logic is unit-tested with `deno test` and the SQL
> is type-/syntax-reviewed, but the two SQL-level invariants above are proven
> only in the consumer repo against a live database — they are **not** runtime-
> proven in this harness.
