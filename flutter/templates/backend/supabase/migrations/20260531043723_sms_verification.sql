-- 20260531043723_sms_verification.sql
--
-- Self-hosted SMS verification — schema, RLS, and atomic RPCs.
--
-- TEMPLATE: this migration ships in the reusable backend template. The consumer
-- (yipark) places it under `supabase/migrations/` with a fresh timestamp and
-- applies it via the project workflow (`npm run db:migrate` / `supabase db push`).
--
-- DDL-ONLY (db-essentials rule): no demo/seed data. RLS enforces that
-- `sms_verifications` and the `profiles.phone_verified` column are writable by
-- the service-role (server) ONLY; clients can never write them (H-6).
--
-- §8-A mapping:
--   C-1  : `attempts`/`max_attempts` columns back the per-code 5-attempt cap;
--          `sms_rate_events` + RPCs back the multi-layer rate limiter.
--   H-6  : phone_verified server-only write (RLS below).
--   code : only `code_hash` is stored — never the plaintext code.

-- =====================================================================
-- 1. sms_verifications — one row per issued code (hash only)
-- =====================================================================
create table if not exists public.sms_verifications (
  id            uuid primary key default gen_random_uuid(),
  phone         text        not null,
  code_hash     text        not null,             -- HMAC-SHA256(code, pepper); plaintext NEVER stored
  requested_by  uuid        not null references auth.users (id) on delete cascade, -- HIGH fix: code is bound to the requesting (authenticated) user; verify rejects a code claimed by a different user (number-takeover block).
  attempts      int         not null default 0,
  max_attempts  int         not null default 5,
  expires_at    timestamptz not null,
  consumed_at   timestamptz,                       -- non-null => spent (single-use)
  request_ip    text,
  created_at    timestamptz not null default now()
);

comment on table public.sms_verifications is
  'Self-hosted SMS verification codes. code_hash = HMAC-SHA256(code, server pepper). Server-only writes (RLS). Single active code per phone enforced in app logic. requested_by binds each code to the authenticated requester so a code cannot be redeemed by another account.';

-- HIGH fix (takeover): the user who requested the code must be the user who
-- verifies it. `requested_by` is checked against the verify caller's JWT subject.
--
-- Standalone template: the create-table above defines `requested_by uuid not
-- null references auth.users` directly. The idempotent block below is ONLY for a
-- consumer repo where `sms_verifications` already exists from an earlier copy of
-- this template WITHOUT the column. There it is added as nullable (existing rows
-- cannot be back-filled) + FK; the consumer should then prune old rows and run
-- `alter table public.sms_verifications alter column requested_by set not null;`
-- once no NULL rows remain. New inserts always set requested_by (server-enforced).
alter table public.sms_verifications add column if not exists requested_by uuid;
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'sms_verifications_requested_by_fkey'
      and table_name = 'sms_verifications'
  ) then
    alter table public.sms_verifications
      add constraint sms_verifications_requested_by_fkey
      foreign key (requested_by) references auth.users (id) on delete cascade;
  end if;
end$$;

create index if not exists idx_sms_verifications_requested_by on public.sms_verifications (requested_by);
create index if not exists idx_sms_verifications_phone      on public.sms_verifications (phone);
create index if not exists idx_sms_verifications_expires_at on public.sms_verifications (expires_at);
create index if not exists idx_sms_verifications_created_at on public.sms_verifications (created_at);
-- Hot path: latest unconsumed code for a phone.
create index if not exists idx_sms_verifications_phone_unconsumed
  on public.sms_verifications (phone, created_at desc)
  where consumed_at is null;

alter table public.sms_verifications enable row level security;
-- Deny by default. Service-role bypasses RLS, so NO permissive policy is granted
-- to anon/authenticated for write. Clients cannot read codes either (privacy).
-- (Intentionally no SELECT/INSERT/UPDATE/DELETE policy for client roles.)

-- =====================================================================
-- 2. sms_rate_events — multi-layer rate-limit counters (windowed)
-- =====================================================================
create table if not exists public.sms_rate_events (
  id          bigint generated always as identity primary key,
  rate_key    text        not null,    -- e.g. 'phone:+8210...:phone_5min', 'ip:1.2.3.4:ip_24h', 'global:global_1m'
  created_at  timestamptz not null default now()
);

comment on table public.sms_rate_events is
  'Append-only rate-limit hit ledger. Windowed counts computed in count_rate_events RPC. Server-only.';

create index if not exists idx_sms_rate_events_key_time
  on public.sms_rate_events (rate_key, created_at desc);

alter table public.sms_rate_events enable row level security;
-- Server-only; no client policy (service-role bypasses RLS).

-- =====================================================================
-- 3. profiles — phone + phone_verified (TEMPLATE minimal definition)
-- =====================================================================
-- NOTE FOR yipark: the live project already has a profiles/users table. Do NOT
-- recreate it — instead run only the `alter table` column adds below against the
-- real table, and drop this `create table` block. The minimal definition here
-- exists so `supabase db reset` succeeds standalone in the template repo.
create table if not exists public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  phone              text,
  phone_verified     boolean     not null default false,
  phone_verified_at  timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- Idempotent column adds for the case where profiles already exists in yipark.
alter table public.profiles add column if not exists phone             text;
alter table public.profiles add column if not exists phone_verified    boolean not null default false;
alter table public.profiles add column if not exists phone_verified_at timestamptz;

comment on column public.profiles.phone_verified is
  'Server-only write (set by sms-verify-code Edge function via service-role). Clients may READ their own value but never UPDATE it.';

-- HIGH fix (takeover): a single phone number may be VERIFIED on at most one
-- profile. Partial unique index over the verified set only — unverified/legacy
-- rows that happen to share a number are unaffected. markPhoneVerified() relies
-- on this to make a hijack attempt fail at the DB even if app checks regress.
create unique index if not exists uq_profiles_phone_verified
  on public.profiles (phone)
  where phone_verified;

alter table public.profiles enable row level security;

-- Clients may READ their own profile row (incl. phone_verified). Naming: {table}_{role}_{action}.
drop policy if exists profiles_authenticated_select_own on public.profiles;
create policy profiles_authenticated_select_own
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

-- Clients may UPDATE their own profile but are FORBIDDEN from touching the
-- verification columns. Postgres has no per-column UPDATE policy in USING, so we
-- guard via a trigger that rejects client-driven changes to phone_verified /
-- phone_verified_at unless the actor is the service-role.
drop policy if exists profiles_authenticated_update_own on public.profiles;
create policy profiles_authenticated_update_own
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create or replace function public.guard_phone_verified_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- service_role bypasses RLS and runs as the 'service_role' DB role; allow it.
  -- For any other role, block changes to the verified columns (H-6).
  if current_setting('request.jwt.claim.role', true) is distinct from 'service_role'
     and current_user <> 'service_role' then
    if new.phone_verified is distinct from old.phone_verified
       or new.phone_verified_at is distinct from old.phone_verified_at then
      raise exception 'phone_verified columns are server-only';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_guard_phone_verified on public.profiles;
create trigger trg_guard_phone_verified
  before update on public.profiles
  for each row
  execute function public.guard_phone_verified_columns();

-- =====================================================================
-- 4. Atomic RPCs (SECURITY DEFINER, service-role caller)
-- =====================================================================

-- Atomic per-code attempt increment: increments and returns the new count in a
-- single statement so concurrent verify calls cannot race past the cap.
create or replace function public.increment_sms_attempt(p_id uuid)
returns int
language sql
security definer
set search_path = public
as $$
  update public.sms_verifications
     set attempts = attempts + 1
   where id = p_id
  returning attempts;
$$;

comment on function public.increment_sms_attempt(uuid) is
  'Atomic attempts++ for a verification row; returns new attempts count. Service-role only.';

-- Record one rate-limit hit and return the windowed count INCLUDING this hit.
--
-- CRITICAL fix (rate-limit atomicity / toll-fraud): the insert+count must not
-- race. Concurrent requests for the SAME key are serialized via a per-key
-- transaction-scoped advisory lock (pg_advisory_xact_lock). The lock auto-
-- releases at COMMIT/ROLLBACK, and because the key is hashed, only requests for
-- the same rate_key contend — different phones/IPs run fully in parallel, so
-- throughput impact is minimal. This guarantees that N concurrent requests for
-- one key observe count values 1..N (never N copies of the same pre-increment
-- count), which is what the limiter's `count > max` comparison depends on.
create or replace function public.record_rate_event(p_key text, p_window_seconds int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  -- Serialize concurrent inserts for THIS key only (auto-released at xact end).
  perform pg_advisory_xact_lock(hashtextextended(p_key, 0));
  insert into public.sms_rate_events (rate_key) values (p_key);
  select count(*) into v_count
    from public.sms_rate_events
   where rate_key = p_key
     and created_at > now() - make_interval(secs => p_window_seconds);
  return v_count;
end;
$$;

comment on function public.record_rate_event(text, int) is
  'Append a hit and return the count within the trailing window. Atomic via per-key pg_advisory_xact_lock so concurrent same-key requests cannot race past the cap (toll-fraud protection). Service-role only.';

-- Read-only windowed count (no record).
create or replace function public.count_rate_events(p_key text, p_window_seconds int)
returns int
language sql
security definer
set search_path = public
as $$
  select count(*)::int
    from public.sms_rate_events
   where rate_key = p_key
     and created_at > now() - make_interval(secs => p_window_seconds);
$$;

-- Lock down RPC execution to server roles only (service_role). Revoke from
-- anon/authenticated so clients cannot drive the limiter or attempt counter.
revoke all on function public.increment_sms_attempt(uuid)        from public, anon, authenticated;
revoke all on function public.record_rate_event(text, int)       from public, anon, authenticated;
revoke all on function public.count_rate_events(text, int)       from public, anon, authenticated;
grant execute on function public.increment_sms_attempt(uuid)     to service_role;
grant execute on function public.record_rate_event(text, int)    to service_role;
grant execute on function public.count_rate_events(text, int)    to service_role;

-- =====================================================================
-- 5. Housekeeping: prune expired/old rows (call from a scheduled job)
-- =====================================================================
create or replace function public.prune_sms_data(p_retain_days int default 2)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.sms_verifications where created_at < now() - make_interval(days => p_retain_days);
  delete from public.sms_rate_events   where created_at < now() - interval '24 hours';
$$;

revoke all on function public.prune_sms_data(int) from public, anon, authenticated;
grant execute on function public.prune_sms_data(int) to service_role;
