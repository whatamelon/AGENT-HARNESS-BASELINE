// link-resolve/index.ts
//
// Supabase Edge Function entrypoint (Deno). Thin shell for the installed-app
// resolver `GET /functions/v1/link-resolve?code=...`.
//
// Deploy:  supabase functions deploy link-resolve --no-verify-jwt
//          (the app calls this immediately after the OS opens it from a
//           Universal/App Link, which may be before the user is signed in; the
//           response contains ONLY a stored internal route + optional referral
//           code, no user data, so it is safe to leave public. Route-injection
//           is blocked in core: the response route is always a stored, validated
//           internal path, never one supplied by the caller.)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createSupabaseLinkStore,
  type LinkQueryClient,
} from "../_shared/link_store.ts";
import { handleResolve } from "./core.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "GET") {
    return new Response(JSON.stringify({ route: "/" }), { status: 405, headers: JSON_HEADERS });
  }

  const code = new URL(req.url).searchParams.get("code");

  // Service-role read (see link-redirect rationale). H-4: keys from env.
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

  const result = await handleResolve(code, {
    store: createSupabaseLinkStore(supabase as unknown as LinkQueryClient),
    homeRoute: Deno.env.get("DEEPLINK_HOME_ROUTE") ?? "/",
  });

  return new Response(JSON.stringify(result.body), { status: result.status, headers: JSON_HEADERS });
});
