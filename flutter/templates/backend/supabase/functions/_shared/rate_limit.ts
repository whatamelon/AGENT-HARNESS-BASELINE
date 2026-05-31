// _shared/rate_limit.ts
//
// Multi-layer rate limiting for SMS code requests (§8-A C-1).
//
// Layers (all must pass):
//   1. per-phone short window   — 1 request / 5 min
//   2. per-phone hour window    — 3 requests / 1 h
//   3. per-phone day window     — 5 requests / 24 h
//   4. per-IP day window        — IP abuse cap
//   5. global circuit breaker   — platform-wide req/min ceiling to blunt
//                                 toll-fraud / SMS-pumping bursts
//
// Design: the *decision* (which window is exceeded, what retryAfter to return)
// is a pure function over counts, so it is unit-testable without any backend.
// The *counting* is delegated to an injected `RateLimitStore` so the same logic
// runs against a Postgres table (default), Deno KV, or Upstash without change.

/** A counter store backed by the consumer's chosen persistence layer. */
export interface RateLimitStore {
  /**
   * Atomically record one hit for `key` and return the number of hits within
   * the trailing `windowSeconds`. Implementations MUST be atomic
   * (increment-and-read) to avoid burst races under concurrency.
   */
  hit(key: string, windowSeconds: number): Promise<number>;

  /** Count hits for `key` within the trailing window WITHOUT recording one. */
  count(key: string, windowSeconds: number): Promise<number>;
}

/** One rate-limit window rule. */
export interface RateLimitRule {
  readonly name: string;
  readonly windowSeconds: number;
  readonly max: number;
}

/** Default §8-A C-1 windows. Override per-consumer via `RateLimitConfig`. */
export const DEFAULT_RULES = {
  phone5min: { name: "phone_5min", windowSeconds: 5 * 60, max: 1 },
  phoneHour: { name: "phone_1h", windowSeconds: 60 * 60, max: 3 },
  phoneDay: { name: "phone_24h", windowSeconds: 24 * 60 * 60, max: 5 },
  ipDay: { name: "ip_24h", windowSeconds: 24 * 60 * 60, max: 20 },
  globalMinute: { name: "global_1m", windowSeconds: 60, max: 60 },
} as const;

export interface RateLimitConfig {
  readonly phone5min: RateLimitRule;
  readonly phoneHour: RateLimitRule;
  readonly phoneDay: RateLimitRule;
  readonly ipDay: RateLimitRule;
  readonly globalMinute: RateLimitRule;
}

export const DEFAULT_CONFIG: RateLimitConfig = DEFAULT_RULES;

export interface RateLimitDecision {
  readonly allowed: boolean;
  /** Name of the first exceeded rule (only set when blocked). */
  readonly exceeded?: string;
  /** Seconds the caller should wait before retrying (only set when blocked). */
  readonly retryAfter?: number;
}

/** Input snapshot of current counts for the pure decision function. */
export interface RateLimitCounts {
  readonly phone5min: number;
  readonly phoneHour: number;
  readonly phoneDay: number;
  readonly ipDay: number;
  readonly globalMinute: number;
}

/**
 * PURE decision: given current counts (as they would stand AFTER recording the
 * incoming request) and the config, return whether the request is allowed.
 *
 * A request is allowed only if every count is <= its rule's `max`. The first
 * rule that is exceeded (checked tightest-window first) drives `retryAfter`,
 * approximated as the full window length (conservative upper bound).
 */
export function decide(counts: RateLimitCounts, cfg: RateLimitConfig): RateLimitDecision {
  const checks: ReadonlyArray<[number, RateLimitRule]> = [
    [counts.phone5min, cfg.phone5min],
    [counts.phoneHour, cfg.phoneHour],
    [counts.phoneDay, cfg.phoneDay],
    [counts.ipDay, cfg.ipDay],
    [counts.globalMinute, cfg.globalMinute],
  ];
  for (const [count, rule] of checks) {
    if (count > rule.max) {
      return { allowed: false, exceeded: rule.name, retryAfter: rule.windowSeconds };
    }
  }
  return { allowed: true };
}

/**
 * Stateful enforcement against a store. Records one hit per layer and evaluates
 * the pure `decide`. The global breaker and IP layer are recorded too so a
 * single attacker phone cannot exhaust other layers undetected.
 *
 * NOTE: counts include the just-recorded hit (so `max: 1` permits exactly the
 * first request and blocks the second within the window).
 */
export async function enforce(
  store: RateLimitStore,
  phone: string,
  ip: string,
  cfg: RateLimitConfig = DEFAULT_CONFIG,
): Promise<RateLimitDecision> {
  const [phone5min, phoneHour, phoneDay, ipDay, globalMinute] = await Promise.all([
    store.hit(`phone:${phone}:${cfg.phone5min.name}`, cfg.phone5min.windowSeconds),
    store.hit(`phone:${phone}:${cfg.phoneHour.name}`, cfg.phoneHour.windowSeconds),
    store.hit(`phone:${phone}:${cfg.phoneDay.name}`, cfg.phoneDay.windowSeconds),
    store.hit(`ip:${ip}:${cfg.ipDay.name}`, cfg.ipDay.windowSeconds),
    store.hit(`global:${cfg.globalMinute.name}`, cfg.globalMinute.windowSeconds),
  ]);

  return decide({ phone5min, phoneHour, phoneDay, ipDay, globalMinute }, cfg);
}
