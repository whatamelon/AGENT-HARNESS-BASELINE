// link-redirect/index.ts
//
// Supabase Edge Function entrypoint (Deno). Thin shell for the uninstalled-
// browser deep-link fallback `GET /l/:code` (publicly reachable — no JWT, since
// a browser tapping a share link is unauthenticated).
//
// Deploy:  supabase functions deploy link-redirect --no-verify-jwt
//          (public endpoint: it must be reachable by any browser that taps a
//           link. It performs NO writes and exposes NO user data; it only reads
//           a link's route to drive the Play `referrer` and 302s to an
//           allowlisted store / first-party host. H-3 is enforced in core.)
//
// Routing note: configure the host so the public path `/l/:code` reaches this
// function (e.g. a CDN/host rewrite of `/l/*` → `/functions/v1/link-redirect`),
// or call `/functions/v1/link-redirect?code=...` directly. See README-deeplink.md.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  createSupabaseLinkStore,
  type LinkQueryClient,
} from "../_shared/link_store.ts";
import { parseFirstPartyHosts } from "../_shared/redirect_allowlist.ts";
import { handleRedirect } from "./core.ts";

const HTML_HEADERS = { "Content-Type": "text/html; charset=utf-8" };

function env(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

/** Extract the code from `/l/:code` path or `?code=` query. */
function extractCode(req: Request): string | null {
  const url = new URL(req.url);
  const q = url.searchParams.get("code");
  if (q) return q;
  // Path form: take the last non-empty segment after `/l/`.
  const segments = url.pathname.split("/").filter(Boolean);
  const lIdx = segments.lastIndexOf("l");
  if (lIdx >= 0 && segments.length > lIdx + 1) return segments[lIdx + 1];
  // Fall back to the final segment (handles direct `/.../link-redirect/CODE`).
  return segments.length > 0 ? segments[segments.length - 1] : null;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "GET") {
    return new Response("method not allowed", { status: 405 });
  }

  // Service-role read: `links` RLS only grants the creator read of their own
  // rows, but this public path resolves an arbitrary share code, so it must use
  // service-role and expose ONLY safe fields (store enforces this). Keys from
  // Edge env (H-4).
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

  const result = await handleRedirect(extractCode(req), req.headers.get("user-agent"), {
    store: createSupabaseLinkStore(supabase as unknown as LinkQueryClient),
    allowlist: { firstPartyHosts: parseFirstPartyHosts(Deno.env.get("DEEPLINK_FIRST_PARTY_HOSTS")) },
    storeUrls: {
      appStore: env("DEEPLINK_APP_STORE_URL"),
      playStore: env("DEEPLINK_PLAY_STORE_URL"),
    },
  });

  if (result.kind === "redirect") {
    return new Response(null, { status: 302, headers: { Location: result.location } });
  }
  if (result.kind === "html") {
    return new Response(result.html, { status: 200, headers: HTML_HEADERS });
  }
  return new Response("server error", { status: 500 });
});
