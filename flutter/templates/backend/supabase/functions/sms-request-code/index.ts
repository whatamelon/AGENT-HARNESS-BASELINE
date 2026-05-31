// sms-request-code/index.ts
//
// Supabase Edge Function entrypoint (Deno). Thin shell: enforce authentication
// (JWT -> userId), parse request, read env (secrets are env-ONLY, H-4), build
// the service-role client, and delegate to the pure `handleRequestCode` core.
//
// Deploy:  supabase functions deploy sms-request-code   # JWT verification ON
//          (HIGH fix: this endpoint now REQUIRES a valid Supabase JWT. The flow
//           is social-login FIRST, then phone verification, so a JWT already
//           exists. The issued code is bound to the caller's userId
//           (`requested_by`) so it cannot be redeemed by another account, and
//           an unauthenticated party can no longer drive the SMS sender or
//           enumerate numbers. Abuse is bounded by both JWT and C-1 rate limits.)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { generateCode } from "../_shared/code.ts";
import { parseAllowlist } from "../_shared/phone.ts";
import { selectGateway } from "../_shared/sms_gateway.ts";
import {
  createSupabaseVerificationStore,
  createSupabaseRateLimitStore,
  type ServiceRoleClient,
  type RpcClient,
} from "../_shared/store.ts";
import { handleRequestCode } from "./core.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

function clientIp(req: Request): string {
  // Supabase sets x-forwarded-for; take the first hop.
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
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: false }), { status: 405, headers: JSON_HEADERS });
  }

  // --- AuthN gate (HIGH fix): require a valid Supabase JWT, resolve the user.
  // The issued code is bound to this userId via `requested_by`. ---
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) {
    return new Response(JSON.stringify({ ok: false, reason: "unauthenticated" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }
  const authClient = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) {
    return new Response(JSON.stringify({ ok: false, reason: "unauthenticated" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }
  const userId = userData.user.id;

  let phone: unknown;
  try {
    const parsed = await req.json();
    phone = parsed?.phone;
  } catch {
    // Malformed body -> uniform success (do not reveal parsing state).
    return new Response(JSON.stringify({ ok: true, ttlSeconds: 180 }), { status: 200, headers: JSON_HEADERS });
  }
  if (typeof phone !== "string") {
    return new Response(JSON.stringify({ ok: true, ttlSeconds: 180 }), { status: 200, headers: JSON_HEADERS });
  }

  // Service-role client: server-only writes (H-6). Keys from Edge env (H-4).
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

  const result = await handleRequestCode(userId, phone, clientIp(req), {
    rateLimitStore: createSupabaseRateLimitStore(supabase as unknown as RpcClient),
    verificationStore: createSupabaseVerificationStore(supabase as unknown as ServiceRoleClient),
    gateway: selectGateway(Deno.env.get("SMS_PROVIDER"), Deno.env.get("SMS_ALLOW_NOOP") === "1"),
    allowlist: parseAllowlist(Deno.env.get("SMS_PHONE_ALLOWLIST")),
    pepper: env("SMS_CODE_PEPPER"),
    makeCode: generateCode,
  });

  return new Response(JSON.stringify(result.body), { status: result.status, headers: JSON_HEADERS });
});
