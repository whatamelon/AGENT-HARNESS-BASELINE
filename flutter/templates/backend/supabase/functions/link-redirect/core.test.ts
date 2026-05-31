// link-redirect/core.test.ts — Deno test suite for the uninstalled-browser fallback.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRedirect, type RedirectDeps } from "./core.ts";
import { parseFirstPartyHosts } from "../_shared/redirect_allowlist.ts";
import type { LinkRecord, LinkStore } from "../_shared/link_store.ts";

const IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) Safari/604.1";
const ANDROID = "Mozilla/5.0 (Linux; Android 14; Pixel 8) Chrome/124 Mobile Safari/537.36";
const DESKTOP = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124 Safari/537.36";

const STORE_URLS = {
  appStore: "https://apps.apple.com/app/id1234567890",
  playStore: "https://play.google.com/store/apps/details?id=com.example.app",
};

function fakeStore(rows: Record<string, LinkRecord>): LinkStore {
  return {
    findByCode: (code) => Promise.resolve(rows[code] ?? null),
  };
}

function deps(overrides: Partial<RedirectDeps> = {}): RedirectDeps {
  return {
    store: fakeStore({}),
    allowlist: { firstPartyHosts: parseFirstPartyHosts("app.example.com") },
    storeUrls: STORE_URLS,
    ...overrides,
  };
}

Deno.test("redirect: iOS → App Store 302", async () => {
  const r = await handleRedirect("ABCD23WXYZ", IPHONE, deps());
  assertEquals(r.kind, "redirect");
  if (r.kind === "redirect") {
    assertEquals(r.status, 302);
    assertEquals(r.location, STORE_URLS.appStore);
  }
});

Deno.test("redirect: Android with known code → Play Store + referrer 302", async () => {
  const code = "ABCD23WXYZ";
  const store = fakeStore({ [code]: { route: "/onyu/referral", referralCode: "REF1", expiresAt: null } });
  const r = await handleRedirect(code, ANDROID, deps({ store }));
  assertEquals(r.kind, "redirect");
  if (r.kind === "redirect") {
    assertEquals(r.status, 302);
    const u = new URL(r.location);
    assertEquals(u.hostname, "play.google.com");
    assertEquals(u.searchParams.get("referrer"), code);
  }
});

Deno.test("redirect: Android with unknown code → Play Store WITHOUT referrer", async () => {
  const r = await handleRedirect("UNKNOWNXYZ", ANDROID, deps());
  assertEquals(r.kind, "redirect");
  if (r.kind === "redirect") {
    const u = new URL(r.location);
    assertEquals(u.hostname, "play.google.com");
    assertEquals(u.searchParams.get("referrer"), null);
  }
});

Deno.test("redirect: Android with expired code → no referrer", async () => {
  const code = "ABCD23WXYZ";
  const store = fakeStore({
    [code]: { route: "/x", referralCode: null, expiresAt: "2020-01-01T00:00:00Z" },
  });
  const r = await handleRedirect(code, ANDROID, deps({ store, now: () => new Date("2026-01-01T00:00:00Z") }));
  if (r.kind === "redirect") {
    assertEquals(new URL(r.location).searchParams.get("referrer"), null);
  }
});

Deno.test("redirect: desktop → smart-banner HTML 200", async () => {
  const r = await handleRedirect("ABCD23WXYZ", DESKTOP, deps());
  assertEquals(r.kind, "html");
  if (r.kind === "html") {
    assertEquals(r.status, 200);
    assert(r.html.includes("apple-itunes-app"));
    assert(r.html.includes(STORE_URLS.appStore));
    assert(r.html.includes(STORE_URLS.playStore));
  }
});

Deno.test("redirect: null code on iOS still goes to App Store", async () => {
  const r = await handleRedirect(null, IPHONE, deps());
  assertEquals(r.kind, "redirect");
  if (r.kind === "redirect") assertEquals(r.location, STORE_URLS.appStore);
});

Deno.test("redirect: H-3 — misconfigured (non-allowlisted) store URL fails closed (500)", async () => {
  const r = await handleRedirect("ABCD23WXYZ", IPHONE, deps({
    storeUrls: { appStore: "https://evil.com/app", playStore: STORE_URLS.playStore },
  }));
  assertEquals(r.kind, "error");
  if (r.kind === "error") assertEquals(r.status, 500);
});

Deno.test("redirect: H-3 — never redirects to a URL derived from link payload", async () => {
  // Even if a (hypothetically) tampered row carried an external-looking route,
  // the redirect target is always the static store URL, never the row.
  const code = "ABCD23WXYZ";
  const store = fakeStore({ [code]: { route: "/legit", referralCode: null, expiresAt: null } });
  const r = await handleRedirect(code, IPHONE, deps({ store }));
  if (r.kind === "redirect") assertEquals(r.location, STORE_URLS.appStore);
});

Deno.test("redirect: store lookup failure → 500 (no unchecked redirect)", async () => {
  const store: LinkStore = { findByCode: () => Promise.reject(new Error("db down")) };
  const r = await handleRedirect("ABCD23WXYZ", ANDROID, deps({ store }));
  assertEquals(r.kind, "error");
});
