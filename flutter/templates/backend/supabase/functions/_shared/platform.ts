// _shared/platform.ts
//
// User-Agent → platform classification for the deep-link redirect fallback.
//
// CONTEXT (§6 deep-link): when an *installed* app is present, the OS opens the
// link directly via Universal Links (iOS) / App Links (Android) and the server
// is never hit. This module is only used by the `link-redirect` Edge function,
// which serves the *uninstalled-browser* fallback: it inspects the requesting
// browser's UA to pick the right store / smart-banner response.
//
// Robustness: the classifier matches on stable substrings (`iPhone`, `iPad`,
// `Android`, `Macintosh`, `Windows`) that are version-independent, so a UA
// string from a future OS release still resolves correctly. Anything it cannot
// confidently place as a mobile target is treated as `desktop` (smart-banner),
// which is the safe default — we never push a store redirect to an unknown
// client.

export type Platform = "ios" | "android" | "desktop";

/**
 * Classify a raw `User-Agent` header into a redirect platform.
 *
 * Order matters: Android UAs frequently contain the token `Mobile` and some
 * contain `Linux; Android`; iPadOS Safari may masquerade as desktop
 * `Macintosh` but real iPads still send `iPad` in most app webviews, so we
 * check the explicit mobile markers first and only then fall back to desktop.
 *
 * Returns `desktop` for empty / null / unrecognized input (safe default).
 */
export function classifyPlatform(userAgent: string | null | undefined): Platform {
  if (!userAgent) return "desktop";
  const ua = userAgent.toLowerCase();

  // Android first: an Android UA can also contain "linux"/"mobile"; the
  // "android" token is the unambiguous discriminator.
  if (ua.includes("android")) return "android";

  // iOS family. iPadOS 13+ Safari can spoof a desktop "macintosh" UA, but the
  // in-app webview / most mobile contexts still expose "ipad"/"iphone"/"ipod".
  if (ua.includes("iphone") || ua.includes("ipad") || ua.includes("ipod")) {
    return "ios";
  }

  // Everything else (Windows, macOS desktop Safari/Chrome, Linux desktop,
  // bots, unknown) → smart-banner desktop fallback.
  return "desktop";
}
