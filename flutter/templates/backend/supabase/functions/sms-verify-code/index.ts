// sms-verify-code/index.ts
//
// Supabase Edge Function entrypoint (Deno). Enforces authentication (JWT ->
// Supabase user), then delegates to the pure `handleVerifyCode` core.
//
// Deploy:  supabase functions deploy sms-verify-code
//          (JWT verification ON: only an authenticated user may bind a verified
//           phone to their own profile.)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createSupabaseVerificationStore,
  type ServiceRoleClient,
} from "../_shared/store.ts";
import { handleVerifyCode } from "./core.ts";
import { buildAuditEvent, emitAudit } from "../_shared/audit.ts";

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
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ verified: false }), { status: 405, headers: JSON_HEADERS });
  }

  // --- AuthN gate: require a valid Supabase JWT, resolve the user id. ---
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) {
    return new Response(JSON.stringify({ verified: false, reason: "unauthenticated" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }

  // Resolve the user with the anon client + the caller's JWT (validates the token).
  const authClient = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) {
    return new Response(JSON.stringify({ verified: false, reason: "unauthenticated" }), {
      status: 401,
      headers: JSON_HEADERS,
    });
  }
  const userId = userData.user.id;

  let phone: unknown;
  let code: unknown;
  try {
    const parsed = await req.json();
    phone = parsed?.phone;
    code = parsed?.code;
  } catch {
    return new Response(JSON.stringify({ verified: false, reason: "invalid" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }
  if (typeof phone !== "string" || typeof code !== "string") {
    emitAudit(buildAuditEvent({
      action: "sms_verify_code",
      outcome: "invalid",
      phone: typeof phone === "string" ? phone : "(none)",
      ip: clientIp(req),
      userId,
    }));
    return new Response(JSON.stringify({ verified: false, reason: "invalid" }), {
      status: 400,
      headers: JSON_HEADERS,
    });
  }

  // Service-role client for the verified-flag write (H-6).
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

  const result = await handleVerifyCode(userId, phone, code, clientIp(req), {
    verificationStore: createSupabaseVerificationStore(supabase as unknown as ServiceRoleClient),
    pepper: env("SMS_CODE_PEPPER"),
  });

  return new Response(JSON.stringify(result.body), { status: result.status, headers: JSON_HEADERS });
});
