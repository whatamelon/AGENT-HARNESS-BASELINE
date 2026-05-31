// _shared/redirect_allowlist.ts
//
// Open-redirect defense (§8-A H-3).
//
// The `link-redirect` Edge function 302-redirects uninstalled browsers to a
// store / first-party page. An open redirect would let an attacker craft a link
// on our trusted domain that bounces a victim to a phishing site. To make that
// impossible, EVERY redirect target is checked against a fixed internal host
// allowlist here — the server never reflects a URL taken from user input or
// from a stored `links` row's payload.
//
// Design:
//   - The set of legitimate targets is tiny and static (the two app stores plus
//     the project's own first-party hosts), so it is hard-coded, not
//     data-driven. Stored links carry an internal `route` only (e.g.
//     `/onyu/referral/accept`), never an external URL — see link_code.ts /
//     migration. The route is composed onto a first-party host on the server.
//   - First-party hosts are injected (env-derived) so the template stays
//     domain-agnostic; the consumer (yipark) supplies its real app domain.
//   - `javascript:`, `data:`, protocol-relative `//evil.com`, and any host not
//     on the allowlist are rejected.

/** App Store / Play Store hosts that are always permitted redirect targets. */
const STORE_HOSTS = new Set<string>([
  "apps.apple.com",
  "itunes.apple.com",
  "play.google.com",
]);

/** Schemes we will ever 302 to. Everything else (javascript:, data:, …) is denied. */
const ALLOWED_SCHEMES = new Set<string>(["https:"]);

export interface AllowlistConfig {
  /**
   * First-party hosts the project controls (e.g. `app.example.com`,
   * `link.example.com`). Supplied by the consumer via env; empty in the bare
   * template. Compared case-insensitively, exact host match (no suffix match,
   * so `evil-app.example.com.attacker.com` cannot slip through).
   */
  readonly firstPartyHosts: ReadonlySet<string>;
}

/**
 * Parse a comma-separated env value of first-party hosts into a normalized Set.
 * Each entry is lowercased and stripped of scheme/path if a full URL was given,
 * so both `app.example.com` and `https://app.example.com/` normalize to the
 * bare host. Unparseable entries are dropped.
 */
export function parseFirstPartyHosts(envValue: string | undefined | null): Set<string> {
  const out = new Set<string>();
  if (!envValue) return out;
  for (const raw of envValue.split(",")) {
    const trimmed = raw.trim();
    if (!trimmed) continue;
    const host = extractHost(trimmed);
    if (host) out.add(host.toLowerCase());
  }
  return out;
}

/** Best-effort host extraction: accepts a bare host or a full URL. */
function extractHost(value: string): string | null {
  // Already a bare host (no scheme, no slash) — accept if it looks host-shaped.
  if (!value.includes("/") && !value.includes(":")) {
    return /^[a-z0-9.-]+$/i.test(value) ? value : null;
  }
  try {
    const u = new URL(value.includes("://") ? value : `https://${value}`);
    return u.hostname || null;
  } catch {
    return null;
  }
}

/**
 * Decide whether `url` is a permitted redirect target.
 *
 * Returns true ONLY when ALL hold:
 *   1. `url` parses as an absolute URL (rejects `//evil.com`, relative paths,
 *      `javascript:foo` without a host, malformed input).
 *   2. its scheme is `https:` (rejects `http:`, `javascript:`, `data:`, …).
 *   3. its host is a known store host OR an exact first-party host.
 *
 * This is the single chokepoint for H-3: callers MUST pass any outbound target
 * through here before issuing a 302.
 */
export function isAllowedRedirect(url: string, config: AllowlistConfig): boolean {
  if (!url) return false;

  // Reject protocol-relative (`//host`) explicitly: `new URL("//evil.com")`
  // throws without a base, but be defensive in case a base is ever introduced.
  if (url.startsWith("//")) return false;

  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return false; // relative path, `javascript:` w/o host, garbage → deny
  }

  if (!ALLOWED_SCHEMES.has(parsed.protocol)) return false;

  const host = parsed.hostname.toLowerCase();
  if (STORE_HOSTS.has(host)) return true;
  if (config.firstPartyHosts.has(host)) return true;

  return false;
}

/**
 * Compose a first-party URL from a stored internal `route` and a chosen
 * first-party host, then assert it is allowlisted. Returns the URL string on
 * success or null if the route is unsafe / the host is not first-party.
 *
 * `route` MUST be an absolute path beginning with `/` and may not contain a
 * scheme, host, or `//` (which would turn it into a protocol-relative / absolute
 * URL and bypass the host we control). This guarantees the resulting redirect
 * stays on a first-party host.
 */
export function buildFirstPartyUrl(
  host: string,
  route: string,
  config: AllowlistConfig,
): string | null {
  if (!isSafeInternalRoute(route)) return null;
  const candidate = `https://${host}${route}`;
  return isAllowedRedirect(candidate, config) ? candidate : null;
}

/**
 * A stored route is safe only when it is a single absolute path: starts with a
 * single `/`, is not protocol-relative (`//`), and carries no scheme or host.
 * Query/fragment are permitted (`/a/b?x=1#y`). This is enforced both here and
 * when a link is created so a malicious route can never be persisted nor served.
 */
export function isSafeInternalRoute(route: string | null | undefined): boolean {
  if (!route) return false;
  if (!route.startsWith("/")) return false;
  if (route.startsWith("//")) return false; // protocol-relative
  // No scheme markers / backslashes that browsers may normalize into a host.
  if (route.includes("\\")) return false;
  if (/^\/[^/]*:/.test(route)) return false; // e.g. "/javascript:alert" guard
  return true;
}
