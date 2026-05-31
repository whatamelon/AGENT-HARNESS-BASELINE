// account-delete/store.ts
//
// Persistence seam for account deletion. ALL operations run through the
// SERVICE-ROLE client (RLS bypass) because deletion must reach rows the caller
// can no longer touch once their auth user is gone, and because `auth.admin.*`
// is a privileged API. The handler depends only on the `AccountDeletionStore`
// interface, so unit tests inject an in-memory fake (no live Supabase needed) —
// the same DI pattern as `_shared/store.ts` and `_shared/payment_store.ts`.
//
// The Supabase client is consumed through deliberately narrow structural
// interfaces rather than a hard SDK type import, so this module type-checks off
// the Edge runtime. The real `createClient(...)` instance satisfies the shapes
// at the call site.

/** `{ data, error }` envelope returned by the Supabase calls we await. */
interface Result<T> {
  data: T;
  error: unknown;
}

/**
 * Narrow structural view of the Supabase query + auth-admin client used here.
 * `from(...).update(...).eq(...)` covers the soft-delete writes; `auth.admin`
 * covers the privileged user lookup + deletion.
 */
export interface AdminQueryClient {
  from(table: string): AdminQueryBuilder;
  auth: {
    admin: {
      getUserById(id: string): PromiseLike<Result<{ user: { id: string } | null }>>;
      deleteUser(id: string, shouldSoftDelete?: boolean): PromiseLike<{ data: unknown; error: unknown }>;
    };
  };
}

export interface AdminQueryBuilder {
  update(values: Record<string, unknown>): AdminQueryBuilder;
  delete(): AdminQueryBuilder;
  eq(column: string, value: unknown): AdminQueryBuilder;
  is(column: string, value: null): AdminQueryBuilder;
  select(columns: string): AdminQueryBuilder;
  // Terminal awaitable: PostgREST returns affected rows when a representation is
  // requested; we only need error + a row-count proxy.
  then<R>(onfulfilled: (value: Result<unknown[] | null>) => R): PromiseLike<R>;
}

/** Back-compat alias mirroring store.ts / payment_store.ts naming. */
export type ServiceRoleClient = AdminQueryClient;

/** Server-only account-deletion persistence (service-role). */
export interface AccountDeletionStore {
  /**
   * Whether the auth user still exists. Used for idempotency: a repeat delete
   * for an already-removed user is a safe no-op (`already_deleted`) rather than
   * an error.
   */
  authUserExists(userId: string): Promise<boolean>;

  /**
   * Soft-delete every domain row owned by `userId`, stamping `deleted_at`.
   *
   * ─────────────────────────────────────────────────────────────────────────
   * APP-SPECIFIC CASCADE — FILL THIS IN PER PROJECT.
   * ─────────────────────────────────────────────────────────────────────────
   * The template ships an EMPTY cascade on purpose: which tables hold a user's
   * data, and the `deleted_at` column convention, are domain decisions the
   * consumer owns. Add one `softDeleteTable(...)` call per owned table here
   * (orders, contracts, reservations, profiles, …). The method returns the
   * TOTAL number of rows soft-deleted across all steps (best-effort count for
   * the audit log). It must be idempotent — re-running over already-stamped
   * rows changes 0 additional rows.
   *
   * Soft-delete is preferred over hard-delete for domain rows so that financial
   * / audit / legal-retention records survive account removal (see README:
   * "Soft-delete vs hard-delete policy"). The auth user itself IS hard-deleted
   * (below) so the person can re-register and cannot sign in again.
   */
  softDeleteDomainData(userId: string): Promise<number>;

  /**
   * Purge the user's push/device tokens so a deleted account stops receiving
   * notifications and stale tokens are not reused. Hard delete (no retention
   * value in a token). Returns the number of tokens removed.
   */
  purgeDeviceTokens(userId: string): Promise<number>;

  /**
   * Hard-delete the auth user (`auth.admin.deleteUser`). This invalidates all
   * sessions/refresh tokens and removes the sign-in identity. FK rows declared
   * `on delete cascade` against `auth.users` (e.g. `device_tokens`) are removed
   * by the DB as a backstop. Returns `false` if the user was already gone
   * (idempotent), `true` on a successful delete.
   */
  deleteAuthUser(userId: string): Promise<boolean>;
}

/** True when a Supabase/PostgREST error indicates "user not found". */
function isUserNotFound(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const e = error as { status?: unknown; code?: unknown; message?: unknown };
  if (e.status === 404) return true;
  if (typeof e.code === "string" && e.code === "user_not_found") return true;
  if (typeof e.message === "string" && /not\s*found/i.test(e.message)) return true;
  return false;
}

/** Count affected rows from a PostgREST `.select()`-returning write. */
function rowCount(data: unknown[] | null): number {
  return Array.isArray(data) ? data.length : 0;
}

/**
 * A single idempotent soft-delete step the consumer composes inside
 * `softDeleteDomainData`. Stamps `deleted_at=now()` on rows owned by `userId`
 * that are NOT already stamped (so a re-run changes 0 rows). Returns rows
 * changed.
 *
 * Example (in a project-specific `softDeleteDomainData`):
 *   let total = 0;
 *   total += await softDeleteTable(client, "orders",       "user_id", userId);
 *   total += await softDeleteTable(client, "reservations", "user_id", userId);
 *   total += await softDeleteTable(client, "profiles",     "id",      userId);
 *   return total;
 */
export async function softDeleteTable(
  client: AdminQueryClient,
  table: string,
  ownerColumn: string,
  userId: string,
  deletedAtColumn = "deleted_at",
): Promise<number> {
  const now = new Date().toISOString();
  const res = await client
    .from(table)
    .update({ [deletedAtColumn]: now })
    .eq(ownerColumn, userId)
    .is(deletedAtColumn, null)
    .select("*");
  if (res.error) throw new Error(`softDelete ${table} failed`);
  return rowCount(res.data);
}

/**
 * Service-role-backed account-deletion store.
 *
 * @param client          service-role Supabase client (RLS bypass + auth.admin)
 * @param softDeleteHook  app-specific domain cascade. Defaults to a NO-OP that
 *                        returns 0 — the consumer MUST supply a real cascade
 *                        (compose `softDeleteTable` calls) to actually scrub
 *                        domain data. The no-op default keeps the template
 *                        deployable and the auth-user delete working, but a
 *                        production consumer that leaves it empty will only
 *                        remove the auth identity + device tokens.
 * @param deviceTokensTable  override if the project names the table differently.
 */
export function createSupabaseAccountDeletionStore(
  client: AdminQueryClient,
  softDeleteHook: (userId: string) => Promise<number> = () => Promise.resolve(0),
  deviceTokensTable = "device_tokens",
): AccountDeletionStore {
  return {
    async authUserExists(userId) {
      const res = await client.auth.admin.getUserById(userId);
      if (res.error) {
        if (isUserNotFound(res.error)) return false;
        throw new Error("authUserExists failed");
      }
      return res.data?.user != null;
    },

    softDeleteDomainData(userId) {
      // Delegates to the app-specific cascade (see README). Empty by default.
      return softDeleteHook(userId);
    },

    async purgeDeviceTokens(userId) {
      const res = await client
        .from(deviceTokensTable)
        .delete()
        .eq("user_id", userId)
        .select("*");
      if (res.error) throw new Error("purgeDeviceTokens failed");
      return rowCount(res.data);
    },

    async deleteAuthUser(userId) {
      const res = await client.auth.admin.deleteUser(userId);
      if (res.error) {
        if (isUserNotFound(res.error)) return false; // idempotent: already gone
        throw new Error("deleteAuthUser failed");
      }
      return true;
    },
  };
}
