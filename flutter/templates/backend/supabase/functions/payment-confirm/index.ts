// payment-confirm/index.ts
//
// Supabase Edge Function entrypoint (Deno). Enforces authentication (JWT ->
// Supabase user), then delegates to the pure `handleConfirm` core (§8-A C-2).
//
// Deploy:  supabase functions deploy payment-confirm
//          (JWT verification ON: only the order owner may confirm.)
//
// AMOUNT SoT: the client body is `{orderId, paymentKey}` — NO amount. The amount
// sent to Toss is the order's DB amount, re-checked against the Toss response.
// TOSS_SECRET_KEY + service-role key are Edge env only (H-4).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createSupabaseOrderStore,
  type ServiceRoleClient,
} from "../_shared/payment_store.ts";
import { createTossClient, type FetchLike } from "../_shared/toss_client.ts";
import { handleConfirm } from "./core.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: JSON_HEADERS });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!token) {
    return new Response(JSON.stringify({ error: "unauthenticated" }), { status: 401, headers: JSON_HEADERS });
  }
  const authClient = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) {
    return new Response(JSON.stringify({ error: "unauthenticated" }), { status: 401, headers: JSON_HEADERS });
  }
  const userId = userData.user.id;

  let orderId: unknown;
  let paymentKey: unknown;
  try {
    const parsed = await req.json();
    orderId = parsed?.orderId;
    paymentKey = parsed?.paymentKey;
  } catch {
    return new Response(JSON.stringify({ error: "invalid" }), { status: 400, headers: JSON_HEADERS });
  }
  if (typeof orderId !== "string" || typeof paymentKey !== "string") {
    return new Response(JSON.stringify({ error: "invalid" }), { status: 400, headers: JSON_HEADERS });
  }

  // Service-role client for the order transition (H-4).
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const tossClient = createTossClient(env("TOSS_SECRET_KEY"), fetch as unknown as FetchLike);

  const result = await handleConfirm(userId, orderId, paymentKey, {
    orderStore: createSupabaseOrderStore(supabase as unknown as ServiceRoleClient),
    tossClient,
  });

  return new Response(JSON.stringify(result.body), { status: result.status, headers: JSON_HEADERS });
});
