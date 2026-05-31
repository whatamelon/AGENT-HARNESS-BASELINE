// link-redirect/core.ts
//
// Pure, dependency-injected core for the uninstalled-browser deep-link fallback
// (`GET /l/:code`). Kept free of the Deno serve runtime so it is unit-testable:
// the link store, allowlist config, store URLs, and clock are injected.
//
// FLOW (§6 deep-link):
//   - An INSTALLED app never reaches this endpoint: iOS Universal Links and
//     Android App Links cause the OS to open the app directly from the tapped
//     https URL. This core only runs for browsers WITHOUT the app installed.
//   - It resolves the `code` → an internal route, then redirects by platform:
//       ios      → App Store (302)
//       android  → Play Store with `?referrer=<code>` (302; Play Install
//                  Referrer lets the freshly-installed app recover the code →
//                  deferred deep link)
//       desktop  → a smart-banner HTML page (no store push to unknown clients)
//
// SECURITY (§8-A H-3):
//   - EVERY redirect target is built from a static store URL or a first-party
//     host + stored internal route and is re-checked via `isAllowedRedirect`.
//     The server never reflects a URL from the link payload or query string, so
//     an open redirect is impossible.
//   - Unknown / expired codes do NOT 404-leak existence; they fall back to the
//     desktop smart-banner / store home, which is also allowlisted.

import { classifyPlatform } from "../_shared/platform.ts";
import { canonicalizeLinkCode } from "../_shared/link_code.ts";
import {
  type AllowlistConfig,
  isAllowedRedirect,
} from "../_shared/redirect_allowlist.ts";
import type { LinkStore } from "../_shared/link_store.ts";

export interface StoreUrls {
  /** App Store product URL (e.g. https://apps.apple.com/app/idXXXXXXXXX). */
  readonly appStore: string;
  /** Play Store details URL (e.g. https://play.google.com/store/apps/details?id=...). */
  readonly playStore: string;
}

export interface RedirectDeps {
  readonly store: LinkStore;
  readonly allowlist: AllowlistConfig;
  readonly storeUrls: StoreUrls;
  /** Injectable clock for deterministic expiry checks in tests. */
  readonly now?: () => Date;
}

export type RedirectResult =
  | { kind: "redirect"; status: 302; location: string }
  | { kind: "html"; status: 200; html: string }
  | { kind: "error"; status: 500 };

/**
 * Append the Play `referrer` param so the installed app can recover the link
 * code (deferred deep link). The base URL is validated/allowlisted by the
 * caller; we only attach a query param to a URL we already trust.
 */
function withReferrer(playStoreUrl: string, code: string): string {
  const u = new URL(playStoreUrl);
  u.searchParams.set("referrer", code);
  return u.toString();
}

/** Minimal, self-contained smart-banner page for desktop / unknown clients. */
function smartBannerHtml(appStore: string, playStore: string): string {
  // No user-controlled data is interpolated — store URLs are server config and
  // already allowlisted, so this page cannot be turned into an injection sink.
  return [
    "<!doctype html>",
    '<html lang="ko"><head>',
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    // iOS Safari smart app banner (only renders when an apple-itunes-app meta
    // app-id is present; harmless elsewhere).
    '<meta name="apple-itunes-app" content="app-id=APP_STORE_ID_PLACEHOLDER">',
    "<title>앱에서 열기</title>",
    "</head><body>",
    "<p>이 링크는 앱에서 열립니다. 앱을 설치하거나 열어 주세요.</p>",
    `<p><a href="${appStore}" rel="noopener">App Store</a> · `,
    `<a href="${playStore}" rel="noopener">Google Play</a></p>`,
    "</body></html>",
  ].join("");
}

/**
 * Resolve a deep-link code and produce the correct uninstalled-browser fallback
 * response for the requesting platform.
 *
 * `rawCode` and `userAgent` come straight from the request; everything else is
 * injected. The function performs NO I/O beyond the injected store lookup.
 */
export async function handleRedirect(
  rawCode: string | null,
  userAgent: string | null,
  deps: RedirectDeps,
): Promise<RedirectResult> {
  const platform = classifyPlatform(userAgent);

  // Pre-validate the static store URLs once: if config is wrong, fail closed
  // rather than emit an unchecked redirect.
  if (
    !isAllowedRedirect(deps.storeUrls.appStore, deps.allowlist) ||
    !isAllowedRedirect(deps.storeUrls.playStore, deps.allowlist)
  ) {
    return { kind: "error", status: 500 };
  }

  // Resolve the code only to drive the Play `referrer` (deferred deep link) and
  // to honor expiry. The redirect TARGET is always a store URL — never a
  // URL derived from the link row — so H-3 holds regardless of the lookup.
  const code = canonicalizeLinkCode(rawCode);
  let referrerCode: string | null = null;
  if (code) {
    let record;
    try {
      record = await deps.store.findByCode(code);
    } catch {
      return { kind: "error", status: 500 };
    }
    if (record) {
      const expired =
        record.expiresAt !== null &&
        new Date(record.expiresAt).getTime() <= (deps.now ?? (() => new Date()))().getTime();
      if (!expired) referrerCode = code;
    }
  }

  if (platform === "ios") {
    const location = deps.storeUrls.appStore;
    // Already validated above.
    return { kind: "redirect", status: 302, location };
  }

  if (platform === "android") {
    const location = referrerCode
      ? withReferrer(deps.storeUrls.playStore, referrerCode)
      : deps.storeUrls.playStore;
    // Re-validate: withReferrer keeps the host, but re-checking is the H-3
    // contract — never trust a composed URL without the chokepoint.
    if (!isAllowedRedirect(location, deps.allowlist)) {
      return { kind: "error", status: 500 };
    }
    return { kind: "redirect", status: 302, location };
  }

  // desktop / unknown → smart banner (no store push).
  return {
    kind: "html",
    status: 200,
    html: smartBannerHtml(deps.storeUrls.appStore, deps.storeUrls.playStore),
  };
}
