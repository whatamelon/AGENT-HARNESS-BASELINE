// _shared/rate_limit.test.ts — Deno test suite for multi-layer rate limiting.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decide,
  DEFAULT_CONFIG,
  enforce,
  type RateLimitCounts,
  type RateLimitStore,
} from "./rate_limit.ts";

function counts(p: Partial<RateLimitCounts>): RateLimitCounts {
  return { phone5min: 0, phoneHour: 0, phoneDay: 0, ipDay: 0, globalMinute: 0, ...p };
}

Deno.test("decide: all under limit -> allowed", () => {
  const d = decide(counts({ phone5min: 1, phoneHour: 1, phoneDay: 1, ipDay: 1, globalMinute: 1 }), DEFAULT_CONFIG);
  assert(d.allowed);
});

Deno.test("decide: per-phone 5min cap (max 1) blocks 2nd", () => {
  const d = decide(counts({ phone5min: 2 }), DEFAULT_CONFIG);
  assert(!d.allowed);
  assertEquals(d.exceeded, "phone_5min");
  assertEquals(d.retryAfter, DEFAULT_CONFIG.phone5min.windowSeconds);
});

Deno.test("decide: per-phone hour cap (max 3)", () => {
  assert(decide(counts({ phoneHour: 3 }), DEFAULT_CONFIG).allowed === true);
  const d = decide(counts({ phoneHour: 4 }), DEFAULT_CONFIG);
  assert(!d.allowed);
  assertEquals(d.exceeded, "phone_1h");
});

Deno.test("decide: per-phone day cap (max 5)", () => {
  const d = decide(counts({ phoneDay: 6 }), DEFAULT_CONFIG);
  assert(!d.allowed);
  assertEquals(d.exceeded, "phone_24h");
});

Deno.test("decide: global circuit breaker (max 60/min)", () => {
  const d = decide(counts({ globalMinute: 61 }), DEFAULT_CONFIG);
  assert(!d.allowed);
  assertEquals(d.exceeded, "global_1m");
});

Deno.test("decide: tightest window reported first", () => {
  // Both phone5min and phoneDay exceeded; 5min (checked first) wins.
  const d = decide(counts({ phone5min: 2, phoneDay: 99 }), DEFAULT_CONFIG);
  assertEquals(d.exceeded, "phone_5min");
});

// In-memory store to exercise `enforce` end-to-end.
class FakeStore implements RateLimitStore {
  private hits = new Map<string, number>();
  hit(key: string): Promise<number> {
    const n = (this.hits.get(key) ?? 0) + 1;
    this.hits.set(key, n);
    return Promise.resolve(n);
  }
  count(key: string): Promise<number> {
    return Promise.resolve(this.hits.get(key) ?? 0);
  }
}

Deno.test("enforce: first request allowed, second within 5min blocked", async () => {
  const store = new FakeStore();
  const first = await enforce(store, "+821012345678", "1.2.3.4");
  assert(first.allowed);
  const second = await enforce(store, "+821012345678", "1.2.3.4");
  assert(!second.allowed);
  assertEquals(second.exceeded, "phone_5min");
});

Deno.test("enforce: independent phones do not share the per-phone window", async () => {
  const store = new FakeStore();
  assert((await enforce(store, "+821011110000", "1.2.3.4")).allowed);
  assert((await enforce(store, "+821022220000", "1.2.3.4")).allowed); // different phone, still ok
});

// CRITICAL fix (atomicity) — coverage boundary.
//
// `decide` enforces `count > max`, which is only sound if each concurrent
// same-key request observes a DISTINCT incremented count (1..N). That guarantee
// lives in the SQL `record_rate_event` RPC (per-key pg_advisory_xact_lock) and
// CANNOT be exercised from Deno (no live Postgres in the harness). The
// concurrency correctness of the advisory lock is verified in the consumer
// (yipark) against a live Postgres — see README "Live verification (deferred)".
//
// What we CAN assert here: given the store contract (atomic distinct counts),
// the decision logic blocks the moment the count exceeds the cap. This models
// the post-fix invariant: N=2 concurrent first-window requests yield counts
// {1,2}; the count==2 caller is blocked.
Deno.test("decide models atomic distinct counts: 2nd concurrent same-key request blocked", () => {
  // Simulate the two count values a correctly-atomic store returns for two
  // concurrent requests on the tightest window (max 1).
  const firstCaller = decide(counts({ phone5min: 1 }), DEFAULT_CONFIG);
  const secondCaller = decide(counts({ phone5min: 2 }), DEFAULT_CONFIG);
  assert(firstCaller.allowed);
  assert(!secondCaller.allowed);
  assertEquals(secondCaller.exceeded, "phone_5min");
});
