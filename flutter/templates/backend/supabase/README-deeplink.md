# Deep links — self-hosted link server (Supabase backend template)

Reusable **template** for self-hosted deep links (Universal Links / Android App
Links) plus the uninstalled-browser fallback, on Supabase (Edge Functions +
Postgres). This directory is a *template*, not a live project: a consumer (e.g.
`yipark`) copies the migration + functions + `.well-known` files into its own
tree and hosts them on its real domain.

This is **Lane B** of the Flutter harness P4 (server). It implements the §8-A
**H-3** server gate (open-redirect block) and the link/device-token schema +
RLS. The Flutter client (Lane A) calls `link-resolve` after the OS opens it from
a link, and registers/deletes its push token in `device_tokens`.

> **Honesty boundary**: the harness has **no live Supabase and no real domain**.
> The code here is complete + unit-tested (pure logic) + type-checked. It is
> **not** deployed, hosted, or runtime-proven. Live hosting (`.well-known`
> serving, Apple CDN propagation, App/Universal Link verification on real
> devices) happens in the consumer repo (yipark). Do not read any claim here as
> "deployed" or "working in production".

---

## How deep links actually route (why two endpoints)

```
        user taps  https://link.<domain>/l/ABCD23WXYZ
                              │
            ┌─────────────────┴─────────────────┐
   APP INSTALLED                          APP NOT INSTALLED
   (OS owns the URL)                      (request hits our server)
            │                                     │
   OS opens the app directly via            GET /l/:code → link-redirect
   Universal Link (iOS, from AASA)               │
   / App Link (Android, from               UA = iOS     → 302 App Store
   assetlinks.json). The SERVER            UA = Android  → 302 Play + ?referrer=code
   IS NOT HIT.                             UA = desktop  → smart-banner HTML
            │
   App calls link-resolve(code)
   → { route, referralCode? }
   and navigates in-app.
```

- **`link-redirect` (`GET /l/:code`)** — *only* serves browsers without the app.
  It never serves an installed app (the OS intercepts the https link first). Its
  job is store routing + Play `referrer` for deferred deep links.
- **`link-resolve` (`GET /functions/v1/link-resolve?code=...`)** — called *by the
  installed app* to turn a code into an in-app route (+ optional referral code).

The two `.well-known` files (`apple-app-site-association`, `assetlinks.json`) are
what make the OS claim the https links in the first place. Without them, every
tap falls through to `link-redirect` even when the app is installed.

---

## Layout

```
functions/
├── link-redirect/{index.ts, core.ts, core.test.ts}   # GET /l/:code uninstalled fallback
├── link-resolve/{index.ts, core.ts, core.test.ts}    # GET ?code= installed-app resolve
├── _shared/
│   ├── platform.ts          # UA → ios|android|desktop (version-independent)
│   ├── link_code.ts         # CSPRNG non-sequential Crockford-base32 code + validate
│   ├── redirect_allowlist.ts# H-3 open-redirect chokepoint (host allowlist + safe route)
│   ├── link_store.ts        # service-role links lookup (safe fields only)
│   └── *.test.ts            # Deno test suites (pure logic)
└── well-known/
    ├── apple-app-site-association   # AASA template (NO extension)
    └── assetlinks.json              # Android App Links template
migrations/<ts>_links_and_device_tokens.sql            # links + device_tokens (DDL-only)
```

`core.ts` holds pure, dependency-injected logic (unit-tested with in-memory
fakes). `index.ts` is the thin Deno `serve` shell (env, code extraction, build
service-role client, delegate to core).

---

## §8-A H-3 — open-redirect / injection block (where each control lives)

| Control | Location |
|---------|----------|
| **Redirect target allowlist** (only store hosts + first-party hosts, `https:` only) | `_shared/redirect_allowlist.ts` `isAllowedRedirect()` — the single chokepoint; `link-redirect/core.ts` passes every target through it and **fails closed (500)** on a non-allowlisted target |
| **No external URL is ever stored or reflected** | `links.route` is an INTERNAL absolute path only — enforced by the DB `links_route_internal_chk` CHECK **and** `isSafeInternalRoute()`. The redirect target is always a static store URL, never a value from the link row/query |
| **Non-sequential referral / link code** | `_shared/link_code.ts` `generateLinkCode()` — `crypto.getRandomValues` + rejection sampling over Crockford base32; `Math.random` is never used. `isValidLinkCode()`/`canonicalizeLinkCode()` reject malformed input before any DB lookup |
| **Route-injection block (resolve)** | `link-resolve/core.ts` returns only the stored, re-validated route or the safe `homeRoute`; the request `code` is a lookup key only, never echoed as a route |
| **Deferred deep link via Play referrer** | `link-redirect/core.ts` `withReferrer()` attaches `?referrer=<code>` to the (allowlisted) Play URL so a freshly installed Android app can recover the code |
| **No secrets in code** | all URLs/hosts via `Deno.env.get(...)`; zero literals |

---

## Migration RLS summary

- `links`: RLS enabled.
  - `links_authenticated_select_own` — a user may READ links they created.
  - `links_authenticated_insert_own` — a user may CREATE links attributed to
    themselves (`created_by = auth.uid()`); `route` shape enforced by
    `links_route_internal_chk`.
  - **No anon/public SELECT policy** — clients cannot enumerate links. The public
    redirect/resolve path uses the **service-role** client (RLS bypass) and
    exposes only the safe `route` + referral code.
  - No client UPDATE/DELETE — links are immutable from the client; expiry cleanup
    is a server concern (`prune_expired_links()`, service-role only).
- `device_tokens`: RLS enabled — a user may SELECT / INSERT / UPDATE / DELETE
  **only their own** rows (`user_id = auth.uid()`). This backs **M3**: the client
  deletes its own token on sign-out. `updated_at` is maintained by a trigger.

---

## `.well-known` hosting requirements (the part most teams get wrong)

Both files must be served from the consumer's **production HTTPS domain** at the
exact `.well-known` paths. The OS fetches them; if the response is wrong, link
verification silently fails and every tap falls through to the browser.

### `apple-app-site-association` (AASA) — Apple Universal Links

- **Path**: `https://<domain>/.well-known/apple-app-site-association`
- **No file extension** — the file is literally named `apple-app-site-association`
  (NOT `.json`). Serve it with `Content-Type: application/json`.
- **No redirect** — the response must be a direct `200` with the JSON body. A
  301/302 (even http→https) makes Apple reject it.
- **HTTPS, valid certificate**, reachable from **every IP / geo** (Apple's CDN
  fetches it from its own infrastructure, not the user's network).
- Apple's CDN caches and re-fetches the AASA roughly **weekly**; a fresh app
  install also fetches it. Changes are NOT instant — budget propagation time.
- Replace `TEAMID_PLACEHOLDER.BUNDLEID_PLACEHOLDER` with the real
  `<Apple Team ID>.<Bundle Identifier>` (e.g. `ABCDE12345.com.example.app`).
- `components` claims the paths the app handles (`/l/*`, `/onyu/referral/*`,
  `/park/contract/*`) and `exclude`s everything else so unrelated pages stay in
  the browser. Add the app's `applinks:` associated domain in Xcode capabilities.

### `assetlinks.json` — Android App Links

- **Path**: `https://<domain>/.well-known/assetlinks.json`
- Serve with `Content-Type: application/json`, **no redirect**, valid HTTPS cert.
- Replace `ANDROID_PACKAGE_NAME_PLACEHOLDER` with the app's package name and
  `RELEASE_SHA256_FINGERPRINT_PLACEHOLDER...` with the **release signing key**
  SHA-256 fingerprint, uppercase, colon-separated. If you use Play App Signing,
  use the fingerprint Google Play shows under *App integrity* (the upload key
  fingerprint will NOT verify in production).
- The Android manifest intent filter must set `android:autoVerify="true"` on the
  link host so the OS verifies `assetlinks.json` at install time.
- Multiple signing keys (e.g. debug + release) → add multiple fingerprints to the
  `sha256_cert_fingerprints` array.

### Where to host (consumer / yipark decision)

Two viable options for the consumer's `app.<domain>` / `link.<domain>`:

1. **Static hosting (recommended for `.well-known`)** — serve the two files as
   static assets from the web host / CDN with the exact paths, content-type, and
   **no redirect**. This is the most robust because the OS's strict fetch rules
   (no redirect, every geo) are easiest to satisfy with a plain static file.
2. **Edge Function serving** — a small function can return the files, but you
   must guarantee a direct `200` with `Content-Type: application/json` and **no**
   intermediate redirect (Supabase function URLs and any gateway in front must
   not 30x). Static hosting avoids this footgun.

The `/l/:code` public path should rewrite to the `link-redirect` function (e.g. a
host/CDN rewrite of `/l/*` → `/functions/v1/link-redirect`), or the app/links can
point directly at the function URL. The installed app calls `link-resolve`
directly at its function URL.

---

## Deploy (consumer repo, e.g. yipark)

1. Copy `migrations/<ts>_links_and_device_tokens.sql` into your
   `supabase/migrations/` with a fresh timestamp (greater than your latest).
2. Copy `functions/_shared/{platform,link_code,redirect_allowlist,link_store}.ts`,
   `functions/link-redirect`, `functions/link-resolve` into `supabase/functions/`.
3. Apply the migration via your project workflow (`npm run db:migrate` /
   `supabase db push`). Do **not** apply DDL via Supabase MCP.
4. Host the two `.well-known` files on your production domain (see requirements
   above). Add the associated domain to the Flutter app (iOS `applinks:` + Xcode
   capability; Android intent filter + `autoVerify`).
5. Set Edge function env (see table), then deploy both as **public** functions:
   ```bash
   supabase functions deploy link-redirect --no-verify-jwt
   supabase functions deploy link-resolve  --no-verify-jwt
   ```
6. Schedule `select prune_expired_links();` (e.g. pg_cron) to GC expired links.

---

## Required environment (Edge function config — values NEVER in code)

| Env var | Used by | Purpose |
|---------|---------|---------|
| `SUPABASE_URL` | both | Project URL (Supabase-provided) |
| `SUPABASE_SERVICE_ROLE_KEY` | both | Service-role key — resolves arbitrary share codes; exposes only safe fields. Never ship to the client. |
| `DEEPLINK_APP_STORE_URL` | link-redirect | Full App Store product URL (`https://apps.apple.com/app/idXXXXXXXXXX`) |
| `DEEPLINK_PLAY_STORE_URL` | link-redirect | Full Play details URL (`https://play.google.com/store/apps/details?id=...`) |
| `DEEPLINK_FIRST_PARTY_HOSTS` | link-redirect | Comma-separated first-party hosts (`app.example.com,link.example.com`) added to the H-3 allowlist. Empty = stores only. |
| `DEEPLINK_HOME_ROUTE` | link-resolve | Safe internal fallback route for unknown/expired/missing codes. Defaults to `/`. |

> The store URLs MUST resolve to `apps.apple.com`/`itunes.apple.com` /
> `play.google.com` (built-in allowlist) or a `DEEPLINK_FIRST_PARTY_HOSTS` host,
> or `link-redirect` fails closed with `500` — this is the H-3 guarantee.

---

## Shared contract (Lane A ↔ Lane B)

### `GET /functions/v1/link-resolve?code=<code>`

Called by the installed app right after the OS opens it from a Universal/App
Link. Always returns `200`.

```jsonc
// known code with referral
{ "route": "/onyu/referral/accept", "referralCode": "REF123" }
// known code, no referral
{ "route": "/park/contract/42" }
// unknown / expired / malformed code → safe home fallback
{ "route": "/" }
```

`route` is always a stored, server-validated internal absolute path (never a
value the caller supplied). The app navigates to `route` and, if `referralCode`
is present, applies the referral.

### `GET /l/:code` (or `?code=`)

Uninstalled-browser fallback. `302` to App Store (iOS) / Play Store + `referrer`
(Android), or `200` smart-banner HTML (desktop). Not called by an installed app.

---

## Tests

Pure-logic suites ship as Deno tests (`*.test.ts`). When `deno` is installed:

```bash
cd supabase
deno check functions/link-redirect/*.ts functions/link-resolve/*.ts \
  functions/_shared/{platform,link_code,redirect_allowlist,link_store}.ts
deno test functions/
```

Coverage: UA→platform classification (iPhone/iPad/Android phone+tablet/Mac/Windows/
unknown, version-independent), CSPRNG non-sequential code shape/distribution/
collision-resistance + `Math.random` absence, the H-3 allowlist (store + first-
party allowed; external/suffix-attack/`javascript:`/`data:`/`http:`/protocol-
relative blocked; safe-route gate), `link-redirect` core (per-platform target,
deferred `referrer`, expiry, fail-closed on misconfig/lookup-error, never reflects
a payload URL), and `link-resolve` core (code→route, route-injection block,
expiry, home fallback).

### Live verification (deferred to consumer)

The harness cannot exercise these — they require a real domain + devices:

1. **AASA / assetlinks serving** — correct path, `Content-Type: application/json`,
   **no redirect**, valid HTTPS from every geo; Apple CDN propagation; Android
   `autoVerify` with the **release** signing fingerprint.
2. **Universal/App Link interception** — tapping a link with the app installed
   must open the app directly (server not hit) on real iOS + Android devices.
3. **Deferred deep link** — fresh Android install must recover the `referrer`
   code via the Play Install Referrer API.
4. **`links_route_internal_chk` CHECK** — a live insert of an external/`//`/
   scheme route must be rejected by Postgres (proves the H-3 DB backstop).

> Honesty boundary: the pure logic is unit-tested with `deno test` and the SQL is
> type-/syntax-reviewed, but everything requiring a live domain, device, or
> database (above) is proven only in the consumer repo — **not** in this harness.
