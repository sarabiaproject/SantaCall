-- =========================================================
-- SantaCall – Supabase Schema
-- =========================================================
-- Assumptions:
-- - Using the "public" schema.
-- - Supabase project already created.
-- - Built-in auth schema: auth.users
-- =========================================================

-- 0) EXTENSIONS (for UUID generation)
-- Supabase usually has pgcrypto enabled, but we guard it.
create extension if not exists "pgcrypto";

-- =========================================================
-- 1) PROFILES (Parents)
-- =========================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  first_name text,
  last_name text,
  created_at timestamptz not null default now()
);

comment on table public.profiles is 'Parent profiles linked 1:1 with auth.users';
comment on column public.profiles.id is 'Matches auth.users.id';
comment on column public.profiles.email is 'Parent email (from provider)';

-- Helpful index
create index if not exists idx_profiles_email on public.profiles (email);

-- =========================================================
-- 2) CHILDREN (Multiple children per parent)
-- =========================================================

create table if not exists public.children (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  first_name text not null,
  age integer,
  created_at timestamptz not null default now()
);

comment on table public.children is 'Children associated to a parent account';

create index if not exists idx_children_user_id on public.children (user_id);

-- =========================================================
-- 3) CREDIT WALLETS (One wallet per parent)
-- =========================================================

create table if not exists public.credit_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  balance_seconds integer not null default 0,
  updated_at timestamptz not null default now()
);

comment on table public.credit_wallets is 'Holds current credit balance (in seconds) for each parent';

-- One wallet per user (enforced)
create unique index if not exists ux_credit_wallets_user_id
  on public.credit_wallets (user_id);

-- =========================================================
-- 4) CREDIT TRANSACTIONS (Auditable log)
-- =========================================================

create table if not exists public.credit_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,               -- 'purchase' | 'consumption' | 'refund'
  seconds_delta integer not null,   -- positive (credit), negative (debit)
  source text not null,             -- 'iap_appstore' | 'iap_playstore' | 'call_session' | ...
  external_ref text,                -- receipt id, session id, etc.
  created_at timestamptz not null default now()
);

comment on table public.credit_transactions is 'Immutable log of credit movements per parent';

create index if not exists idx_credit_transactions_user_id
  on public.credit_transactions (user_id);

create index if not exists idx_credit_transactions_created_at
  on public.credit_transactions (created_at);

-- =========================================================
-- 5) CALL SESSIONS (Per child)
-- =========================================================

create table if not exists public.call_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  vapi_session_id text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds integer,
  seconds_charged integer,
  status text,                      -- 'in_progress' | 'completed' | 'moderation_ended' | 'no_credits' | ...
  safety_flag boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table public.call_sessions is 'Voice call sessions with Santa per child';

create unique index if not exists ux_call_sessions_vapi_session_id
  on public.call_sessions (vapi_session_id);

create index if not exists idx_call_sessions_user_id
  on public.call_sessions (user_id);

create index if not exists idx_call_sessions_child_id
  on public.call_sessions (child_id);

create index if not exists idx_call_sessions_created_at
  on public.call_sessions (created_at);

-- =========================================================
-- 6) CALL WISHLIST ITEMS (Structured output per session & child)
-- =========================================================

create table if not exists public.call_wishlist_items (
  id uuid primary key default gen_random_uuid(),
  call_session_id uuid not null references public.call_sessions(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  item_name text not null,
  category text,
  priority integer,                 -- 1 = high, 2 = medium, 3 = low
  notes text,
  created_at timestamptz not null default now()
);

comment on table public.call_wishlist_items is 'Wishlist items extracted during calls with Santa';

create index if not exists idx_call_wishlist_items_call_session_id
  on public.call_wishlist_items (call_session_id);

create index if not exists idx_call_wishlist_items_child_id
  on public.call_wishlist_items (child_id);

-- =========================================================
-- 7) ROW LEVEL SECURITY (RLS)
-- =========================================================
-- You can run this block if you want RLS fully wired.
-- Supabase strongly recommends RLS = ON for all user data tables.
-- =========================================================

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.children enable row level security;
alter table public.credit_wallets enable row level security;
alter table public.credit_transactions enable row level security;
alter table public.call_sessions enable row level security;
alter table public.call_wishlist_items enable row level security;

-- ---------------------------------------------------------
-- PROFILES – each user only sees their own profile
-- ---------------------------------------------------------
create policy "Profiles: user can select own profile"
  on public.profiles
  for select
  using ( auth.uid() = id );

create policy "Profiles: user can insert own profile"
  on public.profiles
  for insert
  with check ( auth.uid() = id );

create policy "Profiles: user can update own profile"
  on public.profiles
  for update
  using ( auth.uid() = id );

-- ---------------------------------------------------------
-- CHILDREN – each parent sees only their children
-- ---------------------------------------------------------
create policy "Children: select own"
  on public.children
  for select
  using ( user_id = auth.uid() );

create policy "Children: insert own"
  on public.children
  for insert
  with check ( user_id = auth.uid() );

create policy "Children: update own"
  on public.children
  for update
  using ( user_id = auth.uid() );

create policy "Children: delete own"
  on public.children
  for delete
  using ( user_id = auth.uid() );

-- ---------------------------------------------------------
-- CREDIT_WALLETS – one per parent, visible only to owner
-- ---------------------------------------------------------
create policy "Wallets: select own"
  on public.credit_wallets
  for select
  using ( user_id = auth.uid() );

create policy "Wallets: update own"
  on public.credit_wallets
  for update
  using ( user_id = auth.uid() );

-- Inserts/changes from Edge Functions (service role) can bypass RLS.

-- ---------------------------------------------------------
-- CREDIT_TRANSACTIONS – visible only to owner
-- ---------------------------------------------------------
create policy "Credit tx: select own"
  on public.credit_transactions
  for select
  using ( user_id = auth.uid() );

-- Inserts usually done via service role in Edge Functions

-- ---------------------------------------------------------
-- CALL_SESSIONS – visible only to owner
-- ---------------------------------------------------------
create policy "Call sessions: select own"
  on public.call_sessions
  for select
  using ( user_id = auth.uid() );

-- Inserts/updates done via Edge Functions using service role (or with explicit checks)

-- ---------------------------------------------------------
-- CALL_WISHLIST_ITEMS – visible only if session belongs to user
-- ---------------------------------------------------------
create policy "Wishlist: select via own sessions"
  on public.call_wishlist_items
  for select
  using (
    exists (
      select 1
      from public.call_sessions cs
      where cs.id = call_session_id
        and cs.user_id = auth.uid()
    )
  );

-- Inserts via Edge Functions with service role, no direct user insert/update needed.

-- =========================================================
-- END OF SCHEMA
-- =========================================================