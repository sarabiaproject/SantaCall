-- =========================================================
-- SantaCall – Database Reset Script
-- =========================================================
-- WARNING: This script will DROP ALL TABLES and DATA.
-- Use with caution.
-- =========================================================

-- 1) DROP EXISTING TABLES & TRIGGERS
-- =========================================================

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

drop table if exists public.call_wishlist_items cascade;
drop table if exists public.call_sessions cascade;
drop table if exists public.credit_transactions cascade;
drop table if exists public.credit_wallets cascade;
drop table if exists public.children cascade;
drop table if exists public.profiles cascade;

-- 2) EXTENSIONS
-- =========================================================
create extension if not exists "pgcrypto";

-- 3) RECREATE TABLES
-- =========================================================

-- PROFILES
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  first_name text,
  last_name text,
  created_at timestamptz not null default now()
);

comment on table public.profiles is 'Parent profiles linked 1:1 with auth.users';
create index idx_profiles_email on public.profiles (email);

-- CHILDREN
create table public.children (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  first_name text not null,
  age integer,
  created_at timestamptz not null default now()
);

comment on table public.children is 'Children associated to a parent account';
create index idx_children_user_id on public.children (user_id);

-- CREDIT WALLETS
create table public.credit_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  balance_seconds integer not null default 0,
  updated_at timestamptz not null default now()
);

comment on table public.credit_wallets is 'Holds current credit balance (in seconds) for each parent';
create unique index ux_credit_wallets_user_id on public.credit_wallets (user_id);

-- CREDIT TRANSACTIONS
create table public.credit_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  seconds_delta integer not null,
  source text not null,
  external_ref text,
  created_at timestamptz not null default now()
);

comment on table public.credit_transactions is 'Immutable log of credit movements per parent';
create index idx_credit_transactions_user_id on public.credit_transactions (user_id);
create index idx_credit_transactions_created_at on public.credit_transactions (created_at);

-- CALL SESSIONS
create table public.call_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  vapi_session_id text not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  duration_seconds integer,
  seconds_charged integer,
  status text,
  safety_flag boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table public.call_sessions is 'Voice call sessions with Santa per child';
create unique index ux_call_sessions_vapi_session_id on public.call_sessions (vapi_session_id);
create index idx_call_sessions_user_id on public.call_sessions (user_id);
create index idx_call_sessions_child_id on public.call_sessions (child_id);
create index idx_call_sessions_created_at on public.call_sessions (created_at);

-- CALL WISHLIST ITEMS
create table public.call_wishlist_items (
  id uuid primary key default gen_random_uuid(),
  call_session_id uuid not null references public.call_sessions(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  item_name text not null,
  category text,
  priority integer,
  notes text,
  created_at timestamptz not null default now()
);

comment on table public.call_wishlist_items is 'Wishlist items extracted during calls with Santa';
create index idx_call_wishlist_items_call_session_id on public.call_wishlist_items (call_session_id);
create index idx_call_wishlist_items_child_id on public.call_wishlist_items (child_id);

-- 4) TRIGGERS & FUNCTIONS
-- =========================================================

-- Trigger to create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5) ROW LEVEL SECURITY (RLS)
-- =========================================================

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.children enable row level security;
alter table public.credit_wallets enable row level security;
alter table public.credit_transactions enable row level security;
alter table public.call_sessions enable row level security;
alter table public.call_wishlist_items enable row level security;

-- PROFILES
create policy "Profiles: user can select own profile" on public.profiles for select using ( auth.uid() = id );
create policy "Profiles: user can insert own profile" on public.profiles for insert with check ( auth.uid() = id );
create policy "Profiles: user can update own profile" on public.profiles for update using ( auth.uid() = id );

-- CHILDREN
create policy "Children: select own" on public.children for select using ( user_id = auth.uid() );
create policy "Children: insert own" on public.children for insert with check ( user_id = auth.uid() );
create policy "Children: update own" on public.children for update using ( user_id = auth.uid() );
create policy "Children: delete own" on public.children for delete using ( user_id = auth.uid() );

-- WALLETS
create policy "Wallets: select own" on public.credit_wallets for select using ( user_id = auth.uid() );
create policy "Wallets: update own" on public.credit_wallets for update using ( user_id = auth.uid() );

-- TRANSACTIONS
create policy "Credit tx: select own" on public.credit_transactions for select using ( user_id = auth.uid() );

-- SESSIONS
create policy "Call sessions: select own" on public.call_sessions for select using ( user_id = auth.uid() );

-- WISHLIST
create policy "Wishlist: select via own sessions" on public.call_wishlist_items for select using (
  exists (
    select 1 from public.call_sessions cs
    where cs.id = call_session_id and cs.user_id = auth.uid()
  )
);
