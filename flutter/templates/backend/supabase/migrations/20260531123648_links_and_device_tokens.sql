-- 20260531123648_links_and_device_tokens.sql
--
-- Deep-link / share-link infrastructure + push device tokens.
--
-- TEMPLATE: ships in the reusable backend template. The consumer (yipark) copies
-- this into `supabase/migrations/` with a fresh timestamp (greater than its
-- latest) and applies it via the project workflow (`npm run db:migrate` /
-- `supabase db push`). DDL-ONLY (db-essentials rule): no demo/seed data.
--
-- §8-A mapping:
--   H-3  : `links.code` is a non-sequential CSPRNG value (generated server-side);
--          `links.route` is constrained to a safe internal absolute path so no
--          external URL can ever be stored or served (open-redirect block).
--   M3   : `device_tokens` RLS lets a user manage ONLY their own tokens, which
--          is what the client uses to delete its token on sign-out.
--
-- The deep-link Edge functions read `links` via the service-role client (the
-- public redirect/resolve path resolves an arbitrary share code) and expose only
-- the safe `route` + referral code — never `created_by` or internal columns.

-- =====================================================================
-- 1. links — short / share / referral links
-- =====================================================================
create table if not exists public.links (
  id               uuid primary key default gen_random_uuid(),
  code             text        not null,             -- non-sequential CSPRNG (Crockford base32); see link_code.ts
  route            text        not null,             -- internal absolute path, e.g. '/onyu/referral/accept'
  referral_payload jsonb,                            -- optional, e.g. {"code":"REF123"}; NEVER an external URL
  created_by       uuid        references auth.users (id) on delete set null,
  expires_at       timestamptz,                      -- null = non-expiring
  created_at       timestamptz not null default now()
);

comment on table public.links is
  'Short/share/referral links. code is a non-sequential CSPRNG value. route is a safe INTERNAL absolute path only (H-3: no external URL is ever stored, so the redirect Edge function cannot be turned into an open redirect). Resolved by link-redirect (uninstalled browser) and link-resolve (installed app) via service-role.';

comment on column public.links.route is
  'Internal absolute path beginning with a single "/" (e.g. /onyu/referral/accept). The CHECK below + server validation (isSafeInternalRoute) forbid scheme/host/protocol-relative values so a stored route cannot become an open redirect or route-injection.';

-- H-3: structurally forbid an external/unsafe route at the DB layer too.
-- Must start with a single '/', must NOT be protocol-relative ('//'), and must
-- not contain a backslash or a scheme-like first segment ('/javascript:...').
alter table public.links
  add constraint links_route_internal_chk
  check (
    route like '/%'
    and route not like '//%'
    and position('\' in route) = 0
    and route !~ '^/[^/]*:'
  );

create unique index if not exists uq_links_code on public.links (code);
create index if not exists idx_links_created_by on public.links (created_by);
create index if not exists idx_links_expires_at on public.links (expires_at);

alter table public.links enable row level security;

-- A user may READ the links they created (e.g. to show their own share links).
-- Naming: {table}_{role}_{action}. The public redirect/resolve path does NOT
-- rely on this policy — it uses the service-role client (RLS bypass) and exposes
-- only safe fields. There is intentionally NO public/anon SELECT policy, so a
-- client cannot enumerate or read arbitrary links.
drop policy if exists links_authenticated_select_own on public.links;
create policy links_authenticated_select_own
  on public.links
  for select
  to authenticated
  using (created_by = auth.uid());

-- A user may CREATE links attributed to themselves. The route shape is enforced
-- by links_route_internal_chk; the code is generated server-side (CSPRNG).
drop policy if exists links_authenticated_insert_own on public.links;
create policy links_authenticated_insert_own
  on public.links
  for insert
  to authenticated
  with check (created_by = auth.uid());

-- (No client UPDATE/DELETE policy: links are immutable from the client. Cleanup
-- of expired links is a server/service-role concern — see prune below.)

-- =====================================================================
-- 2. device_tokens — push notification registration (one row per token)
-- =====================================================================
create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users (id) on delete cascade,
  token       text        not null,
  platform    text        not null,                  -- 'ios' | 'android' (app-validated)
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, token)
);

comment on table public.device_tokens is
  'Push notification device tokens. RLS: a user can read/insert/delete ONLY their own tokens (user_id = auth.uid()), which backs M3 client-side token deletion on sign-out. No service-role-only restriction — token management is a first-party client action.';

create index if not exists idx_device_tokens_user_id on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- M3: the client manages its OWN tokens only. Naming: {table}_{role}_{action}.
drop policy if exists device_tokens_authenticated_select_own on public.device_tokens;
create policy device_tokens_authenticated_select_own
  on public.device_tokens
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists device_tokens_authenticated_insert_own on public.device_tokens;
create policy device_tokens_authenticated_insert_own
  on public.device_tokens
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- Allow upsert-on-conflict refresh of a row the user owns.
drop policy if exists device_tokens_authenticated_update_own on public.device_tokens;
create policy device_tokens_authenticated_update_own
  on public.device_tokens
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists device_tokens_authenticated_delete_own on public.device_tokens;
create policy device_tokens_authenticated_delete_own
  on public.device_tokens
  for delete
  to authenticated
  using (user_id = auth.uid());

-- updated_at maintenance trigger (matches db-essentials common-column rule).
create or replace function public.touch_device_tokens_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_device_tokens_updated_at on public.device_tokens;
create trigger trg_device_tokens_updated_at
  before update on public.device_tokens
  for each row
  execute function public.touch_device_tokens_updated_at();

-- M3 cross-user stale cleanup: a single physical device (FCM/APNs token) can be
-- reused by a *different* user after sign-out/reinstall. The client can only
-- delete its OWN rows under RLS, so it cannot reclaim a token still attributed
-- to the prior user — leaving that user able to receive pushes meant for the
-- new owner. On INSERT of a token, purge every other user's row holding the
-- SAME token, server-side. SECURITY DEFINER runs as the table owner (RLS
-- bypass) so the cross-user delete is allowed; the function only ever deletes
-- rows whose token equals the row being inserted (no broader reach).
create or replace function public.reclaim_device_token_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.device_tokens
   where token = new.token
     and user_id <> new.user_id;
  return new;
end;
$$;

drop trigger if exists trg_device_tokens_reclaim on public.device_tokens;
create trigger trg_device_tokens_reclaim
  before insert on public.device_tokens
  for each row
  execute function public.reclaim_device_token_on_insert();

-- =====================================================================
-- 3. Housekeeping: prune expired links (call from a scheduled job)
-- =====================================================================
create or replace function public.prune_expired_links()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.links
   where expires_at is not null
     and expires_at < now();
$$;

revoke all on function public.prune_expired_links() from public, anon, authenticated;
grant execute on function public.prune_expired_links() to service_role;
