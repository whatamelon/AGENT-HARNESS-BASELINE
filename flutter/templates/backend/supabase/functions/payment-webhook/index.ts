// payment-webhook/index.ts
//
// Supabase Edge Function entrypoint (Deno). Toss calls this — it is NOT
// authenticated by a user JWT, so deploy with `--no-verify-jwt`. Authenticity is
// enforced inside the core by RE-FETCHING the payment from Toss (the webhook
// body is never trusted). See README-payments.md.
//
// Deploy:  supabase functions deploy payment-webhook --no-verify-jwt
//          (public endpoint; security comes from getPayment re-fetch + event_id
//           idempotency, NOT from the request body. TOSS_SECRET_KEY +
//           service-role key are Edge env only (H-4).)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createSupabaseOrderStore,
  createSupabasePaymentEventStore,
  type ServiceRoleClient,
} from "../_shared/payment_store.ts";
import { createTossClient, type FetchLike } from "../_shared/toss_client.ts";
import { handleWebhook } from "./core.ts";

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

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid" }), { status: 400, headers: JSON_HEADERS });
  }

  // Service-role client; both the order transition and the event ledger are
  // server-only writes (H-4).
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const tossClient = createTossClient(env("TOSS_SECRET_KEY"), fetch as unknown as FetchLike);

  const result = await handleWebhook(body, {
    orderStore: createSupabaseOrderStore(supabase as unknown as ServiceRoleClient),
    paymentEventStore: createSupabasePaymentEventStore(supabase as unknown as ServiceRoleClient),
    tossClient,
  });

  return new Response(JSON.stringify(result.body), { status: result.status, headers: JSON_HEADERS });
});
