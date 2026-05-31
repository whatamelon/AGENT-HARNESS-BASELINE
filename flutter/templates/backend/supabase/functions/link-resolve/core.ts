// link-resolve/core.ts
//
// Pure, dependency-injected core for the INSTALLED-app resolve endpoint
// (`GET /functions/v1/link-resolve?code=...`). The store and clock are injected
// so this is unit-testable off the Deno serve runtime.
//
// FLOW (§6 deep-link):
//   - When the app IS installed, the OS opens it directly from the tapped
//     Universal/App Link. The app then calls THIS endpoint with the code to
//     learn which in-app route to navigate to (and any referral code to apply).
//   - The response carries ONLY a stored, server-validated internal `route` —
//     never an arbitrary route from the request — so a caller cannot inject a
//     route to drive the app to an unintended screen (route-injection block).
//   - Unknown / expired codes resolve to a safe home route fallback (200) so the
//     app always has somewhere to land, without leaking which codes exist.

import { canonicalizeLinkCode } from "../_shared/link_code.ts";
import { isSafeInternalRoute } from "../_shared/redirect_allowlist.ts";
import type { LinkStore } from "../_shared/link_store.ts";

export interface ResolveDeps {
  readonly store: LinkStore;
  /**
   * The route the app navigates to when a code is missing/unknown/expired/
   * malformed. MUST be a safe internal route (validated). Typically `/`.
   */
  readonly homeRoute: string;
  /** Injectable clock for deterministic expiry checks in tests. */
  readonly now?: () => Date;
}

export interface ResolveResult {
  readonly status: 200;
  readonly body: {
    readonly route: string;
    readonly referralCode?: string;
  };
}

/**
 * Resolve a deep-link code to an internal route for the installed app.
 *
 * Route-injection defense: the returned `route` is either the link row's stored
 * route (re-validated as a safe internal path) or the configured `homeRoute`.
 * The request's `code` is only ever used as a lookup key, never echoed as a
 * route. A stored route that somehow fails validation is dropped in favor of the
 * home route (fail safe), so no unsafe route can leave this function.
 *
 * @throws if `homeRoute` is not a safe internal route (misconfiguration).
 */
export async function handleResolve(
  rawCode: string | null,
  deps: ResolveDeps,
): Promise<ResolveResult> {
  if (!isSafeInternalRoute(deps.homeRoute)) {
    throw new Error("handleResolve: homeRoute must be a safe internal route");
  }
  const home: ResolveResult = { status: 200, body: { route: deps.homeRoute } };

  const code = canonicalizeLinkCode(rawCode);
  if (!code) return home;

  const record = await deps.store.findByCode(code);
  if (!record) return home;

  const expired =
    record.expiresAt !== null &&
    new Date(record.expiresAt).getTime() <= (deps.now ?? (() => new Date()))().getTime();
  if (expired) return home;

  // Stored route must still pass the safe-route gate (defense in depth: a route
  // is validated on write, re-validated here so a tampered row cannot inject).
  if (!isSafeInternalRoute(record.route)) return home;

  return {
    status: 200,
    body: record.referralCode
      ? { route: record.route, referralCode: record.referralCode }
      : { route: record.route },
  };
}
