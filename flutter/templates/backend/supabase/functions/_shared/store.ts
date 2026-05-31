// _shared/store.ts
//
// Persistence interfaces + Supabase (service-role) implementations.
//
// H-6: ALL writes to `sms_verifications` and to `profiles.phone_verified` go
// through the service-role client here — never the client/anon key. RLS blocks
// client writes entirely (see migration). Handlers depend on these interfaces,
// so unit tests inject in-memory fakes (no live Supabase needed).
//
// The Supabase client is consumed through deliberately narrow structural
// interfaces (`QueryClient`, `RpcClient`) rather than a hard SDK type import, so
// these modules type-check off the Edge runtime. The real `createClient(...)`
// instance satisfies both shapes at the call site.

import type { RateLimitStore } from "./rate_limit.ts";

/** A single verification row as the handlers need it. */
export interface VerificationRow {
  readonly id: string;
  readonly phone: string;
  readonly code_hash: string;
  /** The authenticated user who requested this code (takeover binding). */
  readonly requested_by: string;
  readonly attempts: number;
  readonly max_attempts: number;
  readonly expires_at: string; // ISO
  readonly consumed_at: string | null;
}

/** Server-only verification persistence (service-role). */
export interface VerificationStore {
  /** Invalidate (consume) every outstanding unconsumed code for `phone`. */
  invalidateOutstanding(phone: string): Promise<void>;

  /** Insert a new verification row. Returns the created row id. */
  insert(row: {
    phone: string;
    code_hash: string;
    /** Authenticated requester (takeover binding). */
    requested_by: string;
    max_attempts: number;
    expires_at: string;
    request_ip: string;
  }): Promise<string>;

  /** Latest unconsumed row for `phone`, or null. */
  latestUnconsumed(phone: string): Promise<VerificationRow | null>;

  /**
   * Atomically increment `attempts` for `id` and return the new value (via the
   * `increment_sms_attempt` RPC). Single-statement so concurrent verifies cannot
   * race past the cap.
   */
  incrementAttempts(id: string): Promise<number>;

  /** Mark a row consumed (single-use enforcement). */
  consume(id: string): Promise<void>;

  /**
   * Set `phone_verified=true` (+ phone, verified_at) on the user's profile.
   * Returns `false` when the write is rejected because the number is already
   * verified on a DIFFERENT profile (uq_profiles_phone_verified conflict) —
   * the caller maps that to a failed (not verified) outcome. Returns `true` on
   * success.
   */
  markPhoneVerified(userId: string, phone: string): Promise<boolean>;
}

/** `{ data, error }` envelope returned by all Supabase calls we await. */
interface Result<T> {
  data: T;
  error: unknown;
}

/**
 * Narrow structural view of the Supabase query + rpc client. Each builder
 * method returns `unknown`-friendly chainable objects typed loosely as
 * `QueryBuilder` so the real PostgREST builder satisfies it without an SDK
 * dependency. Terminal calls resolve to a `Result<...>`.
 */
export interface QueryClient {
  from(table: string): QueryBuilder;
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<Result<number | null>>;
}

export interface QueryBuilder {
  insert(values: Record<string, unknown>): QueryBuilder;
  update(values: Record<string, unknown>): QueryBuilder;
  select(columns: string): QueryBuilder;
  eq(column: string, value: unknown): QueryBuilder;
  is(column: string, value: null): QueryBuilder;
  order(column: string, opts: { ascending: boolean }): QueryBuilder;
  limit(n: number): QueryBuilder;
  single(): PromiseLike<Result<{ id?: string } | null>>;
  maybeSingle(): PromiseLike<Result<VerificationRow | null>>;
  // Terminal awaitable for update/insert without a select.
  then<R>(onfulfilled: (value: Result<null>) => R): PromiseLike<R>;
}

/**
 * Supabase-backed verification store. Every method uses the service-role
 * client; RLS is intentionally bypassed for these server-only writes (H-6).
 */
export function createSupabaseVerificationStore(
  client: QueryClient,
  profilesTable = "profiles",
): VerificationStore {
  return {
    async invalidateOutstanding(phone) {
      const now = new Date().toISOString();
      const res = await client
        .from("sms_verifications")
        .update({ consumed_at: now })
        .eq("phone", phone)
        .is("consumed_at", null);
      if (res.error) throw new Error("invalidateOutstanding failed");
    },

    async insert(row) {
      const res = await client
        .from("sms_verifications")
        .insert({
          phone: row.phone,
          code_hash: row.code_hash,
          requested_by: row.requested_by,
          attempts: 0,
          max_attempts: row.max_attempts,
          expires_at: row.expires_at,
          request_ip: row.request_ip,
        })
        .select("id")
        .single();
      if (res.error || !res.data?.id) throw new Error("insert verification failed");
      return res.data.id;
    },

    async latestUnconsumed(phone) {
      const res = await client
        .from("sms_verifications")
        .select("id, phone, code_hash, requested_by, attempts, max_attempts, expires_at, consumed_at")
        .eq("phone", phone)
        .is("consumed_at", null)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (res.error) throw new Error("latestUnconsumed failed");
      return res.data;
    },

    async incrementAttempts(id) {
      // Atomic increment via SECURITY DEFINER RPC (see migration).
      const res = await client.rpc("increment_sms_attempt", { p_id: id });
      if (res.error || res.data === null) throw new Error("incrementAttempts failed");
      return res.data;
    },

    async consume(id) {
      const now = new Date().toISOString();
      const res = await client
        .from("sms_verifications")
        .update({ consumed_at: now })
        .eq("id", id);
      if (res.error) throw new Error("consume failed");
    },

    async markPhoneVerified(userId, phone) {
      const now = new Date().toISOString();
      const res = await client
        .from(profilesTable)
        .update({ phone, phone_verified: true, phone_verified_at: now })
        .eq("id", userId);
      if (res.error) {
        // uq_profiles_phone_verified: number already verified on another
        // profile -> not an internal error, a failed (not verified) outcome.
        if (isUniqueViolation(res.error)) return false;
        throw new Error("markPhoneVerified failed");
      }
      return true;
    },
  };
}

/** True when a Supabase/PostgREST error is a unique-constraint violation (23505). */
function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: unknown }).code === "23505"
  );
}

/** Back-compat alias: handlers may refer to the client as a ServiceRoleClient. */
export type ServiceRoleClient = QueryClient;

/** Rpc-only view for the rate-limit store. */
export interface RpcClient {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<Result<number | null>>;
}

/**
 * Postgres-backed rate-limit store using a `sms_rate_events` table and the
 * `count_rate_events` / `record_rate_event` RPCs (see migration). Atomic via a
 * single insert + windowed count.
 */
export function createSupabaseRateLimitStore(client: RpcClient): RateLimitStore {
  return {
    async hit(key, windowSeconds) {
      const res = await client.rpc("record_rate_event", {
        p_key: key,
        p_window_seconds: windowSeconds,
      });
      if (res.error || res.data === null) throw new Error("rate hit failed");
      return res.data;
    },
    async count(key, windowSeconds) {
      const res = await client.rpc("count_rate_events", {
        p_key: key,
        p_window_seconds: windowSeconds,
      });
      if (res.error || res.data === null) throw new Error("rate count failed");
      return res.data;
    },
  };
}
