# Account deletion — Apple 5.1.1(v) gate (Supabase backend template)

Reusable **template** for in-app account deletion on Supabase (Edge Function +
service-role admin API). Apple App Store **Guideline 5.1.1(v)** requires that any
app supporting account *creation* also let the user *initiate account deletion
from within the app* — missing this is a hard review reject. Google Play has an
equivalent Data deletion requirement. This directory is a *template*, not a live
project: a consumer (e.g. `yipark`) copies the function into its own tree, wires
the domain cascade, and deploys with its own secrets.

This is the server side of the deletion flow. The Flutter client (Lane A) calls
this single endpoint from a "회원 탈퇴" action; the server is authoritative for
*who* may delete *which* account and for the ordering/idempotency of the scrub.

> **Honesty boundary**: the harness has **no live Supabase**. The code here is
> complete + unit-tested (pure logic) + type-checked (`deno check`). It is
> **not** deployed or runtime-proven against a live project — `auth.admin.deleteUser`,
> the real RLS bypass, and the domain cascade are exercised only in the consumer
> repo against a live database.

---

## Layout

```
functions/account-delete/
├── audit.ts        # masked audit logging (email/IP/UA), account-specific vocab
├── audit.test.ts   # masking never leaks raw email/IP/UA
├── store.ts        # service-role persistence seam (auth.admin + soft-delete) + softDeleteTable() helper
├── core.ts         # pure, DI deletion logic (self-only, order-of-ops, idempotency)
├── core.test.ts    # behaviors via in-memory fakes
└── index.ts        # thin Deno serve shell (env, IP/UA, JWT, service-role client, cascade wiring)
```

`core.ts` holds the pure, dependency-injected business logic (unit-tested with
in-memory fakes). `index.ts` is the thin Deno `serve` shell (env, IP, JWT, build
service-role client, **wire the domain cascade**, delegate to core). This mirrors
the SMS (`sms-verify-code`) and payment (`payment-confirm`) functions.

---

## Endpoint

### `POST /functions/v1/account-delete` (also accepts `DELETE`)

**Requires auth** (deploy with JWT verification ON). The caller must present
`Authorization: Bearer <supabase-jwt>`. The account to delete is taken from the
**token's verified `sub`** — the server never trusts a client-supplied id as the
deletion target. The body is OPTIONAL.

Request (body optional — defense-in-depth only):
```json
{ "userId": "<caller-uuid>" }
```
If `userId` is present it MUST equal the token's `sub` (self-only). A mismatch is
`403 forbidden`. An absent or empty body is fine; a non-string `userId` or
malformed JSON is `400 invalid`.

Responses:
| Case | Status | Body |
|------|--------|------|
| Account fully deleted | `200` | `{ "status": "deleted" }` |
| Already deleted (idempotent re-request / concurrent winner) | `200` | `{ "status": "already_deleted" }` |
| Body present but `userId` ≠ token sub | `403` | `{ "error": "forbidden" }` |
| Malformed body | `400` | `{ "error": "invalid" }` |
| Missing/invalid JWT | `401` | `{ "error": "unauthenticated" }` |
| Method other than POST/DELETE | `405` | `{ "error": "method_not_allowed" }` |
| Internal failure (cascade/auth-delete threw) | `500` | `{ "error": "server_error" }` |

A `500` leaves the auth user **intact** (the identity is removed last); every
step is idempotent, so the client may safely retry.

---

## Order of operations (why it matters)

```
1. AuthN gate (JWT -> caller sub)              index.ts
2. Self-only check (targetId == caller)        core.ts   -> 403 on mismatch
3. authUserExists?  no  -> already_deleted      core.ts   (idempotency)
4. soft-delete DOMAIN data (app cascade)        store.ts  <-- WIRE THIS
5. purge device/push tokens                     store.ts
6. auth.admin.deleteUser(uid)  (identity LAST)  store.ts  -> deleted / already_deleted
```

Domain scrub + token purge run **before** the auth identity is removed, so a
mid-flight failure leaves a still-signed-in user (retryable) rather than an
orphaned identity with dangling data. The auth user is the *last* thing removed
because once it is gone the caller's JWT can no longer be re-validated.

---

## Soft-delete vs hard-delete policy

| Target | Strategy | Why |
|--------|----------|-----|
| **Domain rows** (orders, contracts, reservations, payments, …) | **Soft-delete** (`deleted_at = now()`) | Financial / audit / legal-retention records must survive account removal. RLS should hide soft-deleted rows from clients; retain per your data-retention policy, then GC. |
| **Device / push tokens** | **Hard-delete** | A token has no retention value and a stale token causes pushes to a deleted account. |
| **Auth identity** (`auth.users`) | **Hard-delete** (`auth.admin.deleteUser`) | Invalidates all sessions/refresh tokens; lets the person re-register; prevents any further sign-in. FK rows declared `on delete cascade` (e.g. `device_tokens`) are removed by the DB as a backstop. |

> Migrations are **out of scope** for this template — domain schema is the app's
> own (this template ships **no** migration). Your domain tables must carry a
> nullable `deleted_at timestamptz` (see `.claude/rules/core/db-essentials.md`
> common columns). `device_tokens` already exists from the deep-link/push
> template with `user_id ... on delete cascade`.

---

## WIRE THIS: the domain cascade (required per project)

The template ships a **NO-OP cascade** on purpose, so an unwired deploy still
removes the auth identity + device tokens, but it will **not** scrub domain rows.
A production consumer MUST replace the placeholder in `index.ts` with one
`softDeleteTable(...)` call per user-owned table:

```ts
// in index.ts, replace the placeholder `cascade`:
const cascade = async (userId: string): Promise<number> => {
  let n = 0;
  n += await softDeleteTable(client, "orders",       "user_id", userId);
  n += await softDeleteTable(client, "reservations", "user_id", userId);
  n += await softDeleteTable(client, "contracts",    "user_id", userId);
  n += await softDeleteTable(client, "referrals",    "referrer_id", userId);
  n += await softDeleteTable(client, "profiles",     "id",      userId); // PK == auth uid
  return n;
};
```

`softDeleteTable(client, table, ownerColumn, userId, deletedAtColumn="deleted_at")`
stamps `deleted_at=now()` on owned, not-yet-stamped rows (idempotent — a re-run
changes 0 rows) and returns the count. Override `deletedAtColumn` if a table uses
a different name. For tables that must be **hard**-deleted instead, add a method
to `AccountDeletionStore` or extend the cascade with a `.delete()` call.

---

## Security / env (Edge env ONLY, never in code/README)

Read at runtime via `Deno.env.get(...)` in `index.ts`. **No real values appear in
this repo** (key count = 0).

| Env var | Purpose |
|---------|---------|
| `SUPABASE_URL` | Project URL (Supabase-provided) |
| `SUPABASE_ANON_KEY` | Validates the caller's JWT (`auth.getUser`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Privileged deletes — `auth.admin.deleteUser` + RLS-bypass soft-deletes. **Secret. Never ship to the client.** |

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
# SUPABASE_URL / SUPABASE_ANON_KEY are provided by the platform.
```

Controls:
| Control | Location |
|---------|----------|
| **AuthN required** (JWT, `auth.getUser`) | `index.ts` |
| **Self-only** (token sub is the target; body id must match) | `index.ts` + `core.ts` |
| **Privileged deletes via service-role only** | `store.ts` (`auth.admin`, RLS bypass) |
| **Soft-delete domain / hard-delete identity** | `store.ts` + cascade wiring |
| **Idempotency** (already-gone, concurrent winner) | `core.ts` `authUserExists` + `deleteAuthUser` -> `false` |
| **Order-of-ops** (identity removed LAST) | `core.ts` |
| **Masked audit on every branch** (email/IP/UA masked; uuid kept) | `audit.ts` |
| **Secrets in env only** | `index.ts` `Deno.env.get` — zero literals |

---

## Deploy (consumer repo, e.g. yipark)

1. Copy `functions/account-delete/` into your `supabase/functions/`.
2. **Wire the domain cascade** in `index.ts` (see above) — do not deploy the
   no-op placeholder to production.
3. Ensure each user-owned domain table has a nullable `deleted_at` column and
   that client-facing RLS/queries exclude soft-deleted rows.
4. Deploy with JWT verification ON (only an authenticated user may delete their
   own account):
   ```bash
   supabase functions deploy account-delete
   ```
5. Add the client entry point (Flutter "회원 탈퇴"): confirm dialog → call the
   endpoint with the user's bearer token → on `200` sign out locally and route
   to the entry screen.

---

## Tests (deno, pure logic — no live Supabase)

```bash
cd supabase
deno check functions/account-delete/*.ts
deno test functions/account-delete/
```

Coverage:
- **core**: happy-path delete with the scrub→purge→delete ordering asserted;
  self-only (matching `targetId` allowed, foreign `targetId` → `forbidden` with
  zero store calls); both idempotency paths (user gone at first check; concurrent
  winner removes it mid-flight); error path (a throwing scrub step → `500` and
  the auth user is **not** deleted; a throwing auth-delete → `500`, retryable).
- **audit**: `maskEmail` / `maskIp` / `truncateUserAgent` never leak raw values;
  a built event never serializes the raw email.

### Live verification (deferred to consumer)

The harness has no live Postgres/Auth, so these are proven only in the consumer:

1. **`auth.admin.deleteUser` actually invalidates sessions** and cascades the
   `on delete cascade` FKs (e.g. `device_tokens`).
2. **Soft-delete cascade** stamps the real domain tables and the client no longer
   sees the rows (RLS excludes `deleted_at is not null`).
3. **Apple/Google review**: the in-app deletion path is reachable and completes —
   the actual store-review acceptance.
