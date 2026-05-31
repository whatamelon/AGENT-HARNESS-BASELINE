// _shared/link_store.ts
//
// Persistence interface + Supabase (service-role) implementation for `links`.
//
// The deep-link endpoints look up a `links` row by its non-sequential `code` to
// resolve the internal `route` (and optional referral payload). All reads go
// through the service-role client: RLS on `links` only grants the *creator*
// read of their own rows (see migration), so the public redirect/resolve path
// (which has no end-user JWT for an arbitrary share code) must use service-role
// and expose ONLY the safe fields — never the row's `created_by` or internals.
//
// The client is consumed through a narrow structural interface so this module
// type-checks off the Edge runtime (matching store.ts's approach).

/** Safe, public-exposable view of a link row. Never includes creator/internal cols. */
export interface LinkRecord {
  /** Internal absolute route, e.g. `/onyu/referral/accept`. Validated on write+read. */
  readonly route: string;
  /** Optional referral code carried by the link (shown to the installed app). */
  readonly referralCode: string | null;
  /** ISO expiry, or null for non-expiring. */
  readonly expiresAt: string | null;
}

/** Server-only link persistence (service-role). */
export interface LinkStore {
  /** Look up a link by its canonical (uppercase) code, or null when absent. */
  findByCode(code: string): Promise<LinkRecord | null>;
}

interface Result<T> {
  data: T;
  error: unknown;
}

/** Raw row shape as selected from PostgREST. */
interface RawLinkRow {
  route: string;
  referral_payload: { code?: unknown } | null;
  expires_at: string | null;
}

export interface LinkQueryClient {
  from(table: string): LinkQueryBuilder;
}

export interface LinkQueryBuilder {
  select(columns: string): LinkQueryBuilder;
  eq(column: string, value: unknown): LinkQueryBuilder;
  maybeSingle(): PromiseLike<Result<RawLinkRow | null>>;
}

/**
 * Supabase-backed link store. Selects only the safe columns and extracts the
 * referral code from `referral_payload` JSON. The creator id and other internal
 * fields are deliberately never selected, so nothing sensitive can leak through
 * the public resolve/redirect responses.
 */
export function createSupabaseLinkStore(
  client: LinkQueryClient,
  table = "links",
): LinkStore {
  return {
    async findByCode(code) {
      const res = await client
        .from(table)
        .select("route, referral_payload, expires_at")
        .eq("code", code)
        .maybeSingle();
      if (res.error) throw new Error("findByCode failed");
      const row = res.data;
      if (!row) return null;
      const referralCode =
        row.referral_payload && typeof row.referral_payload.code === "string"
          ? row.referral_payload.code
          : null;
      return {
        route: row.route,
        referralCode,
        expiresAt: row.expires_at,
      };
    },
  };
}
