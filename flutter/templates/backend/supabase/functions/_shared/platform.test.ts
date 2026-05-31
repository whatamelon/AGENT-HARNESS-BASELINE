// _shared/platform.test.ts — Deno test suite for UA → platform classification.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { classifyPlatform } from "./platform.ts";

const IPHONE =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1";
const IPAD =
  "Mozilla/5.0 (iPad; CPU OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1";
const ANDROID =
  "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
const ANDROID_TABLET =
  "Mozilla/5.0 (Linux; Android 13; SM-X710) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
const MAC =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15";
const WINDOWS =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

Deno.test("classifyPlatform: iPhone → ios", () => {
  assertEquals(classifyPlatform(IPHONE), "ios");
});

Deno.test("classifyPlatform: iPad → ios", () => {
  assertEquals(classifyPlatform(IPAD), "ios");
});

Deno.test("classifyPlatform: Android phone → android", () => {
  assertEquals(classifyPlatform(ANDROID), "android");
});

Deno.test("classifyPlatform: Android tablet (no 'Mobile') → android", () => {
  assertEquals(classifyPlatform(ANDROID_TABLET), "android");
});

Deno.test("classifyPlatform: macOS desktop → desktop", () => {
  assertEquals(classifyPlatform(MAC), "desktop");
});

Deno.test("classifyPlatform: Windows desktop → desktop", () => {
  assertEquals(classifyPlatform(WINDOWS), "desktop");
});

Deno.test("classifyPlatform: empty / null / unknown → desktop (safe default)", () => {
  assertEquals(classifyPlatform(""), "desktop");
  assertEquals(classifyPlatform(null), "desktop");
  assertEquals(classifyPlatform(undefined), "desktop");
  assertEquals(classifyPlatform("curl/8.4.0"), "desktop");
  assertEquals(classifyPlatform("some-random-bot/1.0"), "desktop");
});

Deno.test("classifyPlatform: version-independent (future OS strings)", () => {
  assertEquals(
    classifyPlatform("Mozilla/5.0 (iPhone; CPU iPhone OS 99_0 like Mac OS X)"),
    "ios",
  );
  assertEquals(
    classifyPlatform("Mozilla/5.0 (Linux; Android 99) Chrome/999"),
    "android",
  );
});

Deno.test("classifyPlatform: case-insensitive", () => {
  assertEquals(classifyPlatform("MOZILLA/5.0 (IPHONE; CPU IPHONE OS 17_4)"), "ios");
  assertEquals(classifyPlatform("mozilla/5.0 (linux; ANDROID 14)"), "android");
});
