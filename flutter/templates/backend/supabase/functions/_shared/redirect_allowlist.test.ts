// _shared/redirect_allowlist.test.ts — Deno test suite for H-3 open-redirect defense.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildFirstPartyUrl,
  isAllowedRedirect,
  isSafeInternalRoute,
  parseFirstPartyHosts,
} from "./redirect_allowlist.ts";

const config = { firstPartyHosts: parseFirstPartyHosts("app.example.com,link.example.com") };

Deno.test("parseFirstPartyHosts: bare hosts and full URLs normalize to host", () => {
  const set = parseFirstPartyHosts("app.example.com, https://link.example.com/, EVIL ");
  assert(set.has("app.example.com"));
  assert(set.has("link.example.com"));
  assert(set.has("evil")); // lowercased; still a host-shaped token
  assertEquals(parseFirstPartyHosts("").size, 0);
  assertEquals(parseFirstPartyHosts(null).size, 0);
});

Deno.test("isAllowedRedirect: store hosts permitted", () => {
  assert(isAllowedRedirect("https://apps.apple.com/app/id123", config));
  assert(isAllowedRedirect("https://itunes.apple.com/app/id123", config));
  assert(isAllowedRedirect("https://play.google.com/store/apps/details?id=x", config));
});

Deno.test("isAllowedRedirect: first-party hosts permitted (exact match)", () => {
  assert(isAllowedRedirect("https://app.example.com/onyu/referral", config));
  assert(isAllowedRedirect("https://link.example.com/l/ABC", config));
});

Deno.test("isAllowedRedirect: blocks arbitrary external hosts", () => {
  assert(!isAllowedRedirect("https://evil.com/phish", config));
  // Suffix-attack: attacker host that merely ends with a trusted label.
  assert(!isAllowedRedirect("https://app.example.com.attacker.com/x", config));
  assert(!isAllowedRedirect("https://play.google.com.evil.com/x", config));
});

Deno.test("isAllowedRedirect: blocks dangerous schemes", () => {
  assert(!isAllowedRedirect("javascript:alert(1)", config));
  assert(!isAllowedRedirect("data:text/html,<script>", config));
  assert(!isAllowedRedirect("http://app.example.com/x", config)); // http not https
  assert(!isAllowedRedirect("ftp://app.example.com/x", config));
});

Deno.test("isAllowedRedirect: blocks protocol-relative and relative input", () => {
  assert(!isAllowedRedirect("//evil.com/x", config));
  assert(!isAllowedRedirect("/onyu/referral", config)); // relative path, no host
  assert(!isAllowedRedirect("", config));
  assert(!isAllowedRedirect("not a url", config));
});

Deno.test("isSafeInternalRoute: only single absolute paths", () => {
  assert(isSafeInternalRoute("/onyu/referral/accept"));
  assert(isSafeInternalRoute("/park/contract?id=1#sec"));
  assert(!isSafeInternalRoute("//evil.com")); // protocol-relative
  assert(!isSafeInternalRoute("https://evil.com")); // absolute URL
  assert(!isSafeInternalRoute("onyu/referral")); // no leading slash
  assert(!isSafeInternalRoute("/javascript:alert(1)")); // scheme-ish segment
  assert(!isSafeInternalRoute("/a\\b")); // backslash
  assert(!isSafeInternalRoute(""));
  assert(!isSafeInternalRoute(null));
});

Deno.test("buildFirstPartyUrl: composes allowlisted first-party URL", () => {
  assertEquals(
    buildFirstPartyUrl("app.example.com", "/onyu/referral/accept?code=ABC", config),
    "https://app.example.com/onyu/referral/accept?code=ABC",
  );
});

Deno.test("buildFirstPartyUrl: rejects non-first-party host even with safe route", () => {
  assertEquals(buildFirstPartyUrl("evil.com", "/onyu/referral", config), null);
});

Deno.test("buildFirstPartyUrl: rejects unsafe route on first-party host", () => {
  assertEquals(buildFirstPartyUrl("app.example.com", "//evil.com", config), null);
  assertEquals(buildFirstPartyUrl("app.example.com", "https://evil.com", config), null);
  assertEquals(buildFirstPartyUrl("app.example.com", "onyu/referral", config), null);
});
