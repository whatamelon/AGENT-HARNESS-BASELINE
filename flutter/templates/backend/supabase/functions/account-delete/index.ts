// account-delete/index.ts
//
// Supabase Edge Function entrypoint (Deno). Enforces authentication (JWT ->
// Supabase user), then delegates to the pure `handleDeleteAccount` core. Backs
// Apple App Store Guideline 5.1.1(v) — in-app account deletion. The Flutter
// client calls this single endpoint from a "회원 탈퇴" action.
//
// Deploy:  supabase functions deploy account-delete
//          (JWT verification ON: only an authenticated user may delete their
//           OWN account. The user id is taken from the verified token's sub.)
//
// Request body is OPTIONAL. If present it may carry `{ "userId": "<uuid>" }`,
// which MUST equal the token's sub (self-only). The endpoint trusts the token,
// not the body — the body match is defense-in-depth only.
//
// SERVICE_ROLE key + admin API are Edge env only (never shipped to the client).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createSupabaseAccountDeletionStore,
  type ServiceRoleClient,
  softDeleteTable,
} from "./store.ts";
import { handleDeleteAccount } from "./core.ts";
import { buildAccountAuditEvent, emitAccountAudit } from "./audit.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

function clientIp(req: Request): string {
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return xff.split(",")[0].trim();
  return req.headers.get("x-real-ip") ?? "0.0.0.0";
}

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

serve(async (req: Request): Promise<Response> => {
  // Accept POST (preferred) or DELETE; reject the rest.
  if (req.method !== "POST" && req.method !== "DELETE") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: JSON_HEADERS,
    });
  }

  const ip = clientIp(req);
  const userAgent = req.headers.get("user-agent") ?? undefined;

  // --- AuthN gate: require a valid Supabase JWT, resolve the user id. ---
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) {
    emitAccountAudit(buildAccountAuditEvent({ outcome: "unauthenticated", ip, userAgent }));
    return new Response(JSON.stringify({ error: "unauthenticated" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  // Validate the token with the anon client + the caller's JWT.
  const authClient = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) {
    emitAccountAudit(buildAccountAuditEvent({ outcome: "unauthenticated", ip, userAgent }));
    return new Response(JSON.stringify({ error: "unauthenticated" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }
  const callerId = userData.user.id;
  const email = userData.user.email ?? undefined;

  // Optional body: a self-only target id. A non-string/non-uuid is rejected as
  // invalid; an absent body is fine (we trust the token's sub).
  let targetId: string | undefined;
  const hasBody = (req.headers.get("content-type") ?? "").includes("application/json");
  if (hasBody) {
    try {
      const parsed = await req.json();
      const raw = parsed?.userId;
      if (raw != null) {
        if (typeof raw !== "string") {
          emitAccountAudit(buildAccountAuditEvent({ outcome: "invalid", userId: callerId, email, ip, userAgent }));
          return new Response(JSON.stringify({ error: "invalid" }), {
            status: 400,
            headers: JSON_HEADERS,
          });
        }
        targetId = raw;
      }
    } catch {
      emitAccountAudit(buildAccountAuditEvent({ outcome: "invalid", userId: callerId, email, ip, userAgent }));
      return new Response(JSON.stringify({ error: "invalid" }), {
        status: 400,
        headers: JSON_HEADERS,
      });
    }
  }

  // Service-role client for the privileged deletes (admin API + RLS bypass).
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // ───────────────────────────────────────────────────────────────────────
  // APP-SPECIFIC DOMAIN CASCADE — WIRE THIS PER PROJECT.
  // ───────────────────────────────────────────────────────────────────────
  // The template ships a NO-OP cascade so an unwired deploy still removes the
  // auth identity + device tokens, but it will NOT scrub domain rows. Replace
  // the body below with one `softDeleteTable(...)` call per user-owned table.
  // Example (yipark): orders, reservations, contracts, referrals, profiles.
  //
  //   const cascade = async (userId: string): Promise<number> => {
  //     let n = 0;
  //     n += await softDeleteTable(client, "orders",       "user_id", userId);
  //     n += await softDeleteTable(client, "reservations", "user_id", userId);
  //     n += await softDeleteTable(client, "profiles",     "id",      userId);
  //     return n;
  //   };
  const client = supabase as unknown as ServiceRoleClient;
  // Reference the helper so an unwired template still imports it (and the
  // consumer has the symbol in scope to compose a real cascade above).
  void softDeleteTable;
  const cascade = (_userId: string): Promise<number> => Promise.resolve(0);

  const result = await handleDeleteAccount(
    { callerId, targetId, email, ip, userAgent },
    { store: createSupabaseAccountDeletionStore(client, cascade) },
  );

  return new Response(JSON.stringify(result.body), { status: result.status, headers: JSON_HEADERS });
});
