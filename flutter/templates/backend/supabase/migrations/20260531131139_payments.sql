-- 20260531131139_payments.sql
--
-- Toss Payments gate — orders + webhook-event ledger, RLS, atomic transition RPC.
--
-- TEMPLATE: ships in the reusable backend template. The consumer (yipark) places
-- it under `supabase/migrations/` with a fresh timestamp and applies it via the
-- project workflow (`npm run db:migrate` / `supabase db push`).
--
-- DDL-ONLY (db-essentials rule): no demo/seed data.
--
-- §8-A C-2 mapping:
--   amount SoT : `orders.amount numeric(15,2)` is the ONLY authoritative amount.
--                ALL writes to orders (amount/status/payment_key) are
--                service-role only (RLS below) — clients can never set them.
--   idempotency: `orders.order_id` UNIQUE + conditional `status='pending'`
--                transition; `payment_events.event_id` UNIQUE dedupes webhooks.
--   H-4        : Toss secret + service-role key live in Edge env, not here.

-- =====================================================================
-- 1. orders — one row per payment order (amount is the server SoT)
-- =====================================================================
create table if not exists public.orders (
  id            uuid          primary key default gen_random_uuid(),
  order_id      text          not null unique,                 -- Toss orderId (client-visible). UNIQUE => idempotency anchor.
  user_id       uuid          not null references auth.users (id) on delete cascade,
  amount        numeric(15,2) not null check (amount > 0),     -- AMOUNT SoT. numeric (no float). server-computed only.
  currency      text          not null default 'KRW',
  order_name    text,
  status        text          not null default 'pending'
                  check (status in ('pending','confirmed','canceled','failed')),
  payment_key   text,                                          -- Toss paymentKey, set on confirm
  confirmed_at  timestamptz,
  created_at    timestamptz   not null default now(),
  updated_at    timestamptz   not null default now()
);

comment on table public.orders is
  'Payment orders. amount (numeric(15,2)) is the server-side Source-of-Truth — set by payment-create-order and never accepted from the client. All writes are service-role only (RLS). order_id UNIQUE anchors idempotent confirm.';
comment on column public.orders.amount is
  'Server-computed authoritative amount in won (numeric(15,2)). Client never supplies this. payment-confirm sends THIS value to Toss and rejects a mismatched Toss response.';

create index if not exists idx_orders_user_id    on public.orders (user_id);
create index if not exists idx_orders_status     on public.orders (status);
create index if not exists idx_orders_created_at on public.orders (created_at);
-- (order_id already has a unique index from the UNIQUE constraint.)

alter table public.orders enable row level security;

-- Clients may READ their OWN orders only. Naming: {table}_{role}_{action}.
drop policy if exists orders_authenticated_select_own on public.orders;
create policy orders_authenticated_select_own
  on public.orders
  for select
  to authenticated
  using (user_id = auth.uid());

-- NO insert/update/delete policy for anon/authenticated: every write
-- (amount, status, payment_key) is performed by the service-role client, which
-- bypasses RLS. This guarantees a client cannot create/alter an amount or move
-- an order's status (tamper block — §8-A C-2).

-- =====================================================================
-- 2. payment_events — webhook delivery ledger (idempotency)
-- =====================================================================
create table if not exists public.payment_events (
  id           uuid        primary key default gen_random_uuid(),
  event_id     text        not null unique,   -- dedupe key (paymentKey:authoritativeStatus). UNIQUE => idempotent webhooks.
  order_id     text,                          -- Toss orderId the event pertains to (nullable: forged/unknown never reach here)
  type         text        not null,          -- eventType (PAYMENT_STATUS_CHANGED, DEPOSIT_CALLBACK, ...)
  raw          jsonb       not null default '{}'::jsonb,  -- minimized authoritative snapshot (no PII)
  processed_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

comment on table public.payment_events is
  'Append-only webhook ledger. event_id UNIQUE guarantees each Toss notification is processed at most once (idempotency). Service-role only — the webhook handler verifies authenticity by re-fetching the payment from Toss before recording.';

create index if not exists idx_payment_events_order_id   on public.payment_events (order_id);
create index if not exists idx_payment_events_created_at on public.payment_events (created_at);

alter table public.payment_events enable row level security;
-- Server-only; no client policy (service-role bypasses RLS).

-- =====================================================================
-- 3. updated_at trigger for orders
-- =====================================================================
create or replace function public.touch_orders_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
  before update on public.orders
  for each row
  execute function public.touch_orders_updated_at();

-- =====================================================================
-- 4. Atomic conditional transition RPC (SECURITY DEFINER, service-role caller)
-- =====================================================================
-- Single-statement conditional transition: moves an order out of 'pending' ONLY
-- if it is still 'pending', returning the affected row count. Concurrent /
-- duplicate confirms therefore observe 1 (the winner) and 0 (idempotent no-op),
-- which is the database-level guarantee the confirm handler relies on (no double
-- approval). The Edge store ALSO performs this as a conditional UPDATE; this RPC
-- is provided for callers that prefer a single round-trip.
create or replace function public.confirm_order_if_pending(
  p_order_id    text,
  p_to_status   text,
  p_payment_key text
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_changed int;
begin
  if p_to_status not in ('confirmed','canceled','failed') then
    raise exception 'illegal target status %', p_to_status;
  end if;
  update public.orders
     set status       = p_to_status,
         payment_key  = p_payment_key,
         confirmed_at = now()
   where order_id = p_order_id
     and status   = 'pending';
  get diagnostics v_changed = row_count;
  return v_changed;
end;
$$;

comment on function public.confirm_order_if_pending(text, text, text) is
  'Atomic pending->terminal transition; returns rows changed (1 winner / 0 duplicate). Service-role only — idempotent confirm anchor (§8-A C-2).';

revoke all on function public.confirm_order_if_pending(text, text, text) from public, anon, authenticated;
grant execute on function public.confirm_order_if_pending(text, text, text) to service_role;
