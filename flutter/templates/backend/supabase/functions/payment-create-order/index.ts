// payment-create-order/index.ts
//
// Supabase Edge Function entrypoint (Deno). Enforces authentication (JWT ->
// Supabase user), then delegates to the pure `handleCreateOrder` core.
//
// Deploy:  supabase functions deploy payment-create-order
//          (JWT verification ON: only an authenticated user may open an order.)
//
// AMOUNT SoT (§8-A C-2): the client body carries ONLY domain items; the amount
// is computed server-side by the injected price resolver and persisted via the
// SERVICE-ROLE client (H-4). The client's amount, if any, is ignored entirely.
//
// INTEGRATION SEAM: `resolvePrice` below is a placeholder that yipark MUST
// replace with a real, server-trusted catalog lookup (its `products` table).
// The template intentionally ships no hard-coded prices.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createSupabaseOrderStore,
  type ServiceRoleClient,
} from "../_shared/payment_store.ts";
import { handleCreateOrder, type OrderLineItem, type PricedOrder } from "./core.ts";

const JSON_HEADERS = { "Content-Type": "application/json" };

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

/**
 * INTEGRATION SEAM — replace in yipark with a server-trusted price lookup.
 *
 * MUST resolve each productId against an authoritative source (the `products`
 * table) using the service-role client, multiply by quantity, and sum. NEVER
 * trust a client-supplied price. Returning null rejects the order.
 */
async function resolvePrice(_items: readonly OrderLineItem[]): Promise<PricedOrder | null> {
  throw new Error(
    "resolvePrice not wired: yipark must implement a server-trusted products lookup (do not accept client amounts)",
  );
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: JSON_HEADERS });
  }

  // --- AuthN gate: require a valid Supabase JWT, resolve the user id. ---
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

  let items: unknown;
  try {
    const parsed = await req.json();
    items = parsed?.items;
  } catch {
    return new Response(JSON.stringify({ error: "invalid" }), { status: 400, headers: JSON_HEADERS });
  }

  // Service-role client for the order insert (H-4 — amount/status server-only).
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

  const result = await handleCreateOrder(userId, items, {
    orderStore: createSupabaseOrderStore(supabase as unknown as ServiceRoleClient),
    priceResolver: resolvePrice,
    generateOrderId: () => crypto.randomUUID(), // CSPRNG; Math.random never used
  });

  return new Response(JSON.stringify(result.body), { status: result.status, headers: JSON_HEADERS });
});
