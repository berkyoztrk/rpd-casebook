-- RPD CASEBOOK - Supabase database schema
-- Run the entire file once in Supabase Dashboard > SQL Editor.
-- Use only the project's publishable/anon key in the browser. NEVER use service_role/secret key here.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'New Member',
  role text not null default 'viewer' check (role in ('admin','detective','viewer')),
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, role, approved)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name',''), split_part(coalesce(new.email,''),'@',1), 'New Member'),
    'viewer',
    false
  ) on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- SECURITY DEFINER helpers prevent RLS recursion on profiles.
create or replace function public.my_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$ select p.role from public.profiles p where p.id = (select auth.uid()) and p.approved = true limit 1; $$;

create or replace function public.is_approved_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.approved = true); $$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.approved = true and p.role = 'admin'); $$;

create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  case_number text not null unique,
  title text not null,
  status text not null default 'Açık',
  priority text not null default 'Normal',
  lead_detective text,
  location text,
  summary text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.evidence (
  id uuid primary key default gen_random_uuid(),
  case_number text not null,
  evidence_number text not null,
  title text not null,
  category text,
  collected_by text,
  collected_at text,
  location text,
  description text,
  chain_of_custody text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.interviews (
  id uuid primary key default gen_random_uuid(),
  case_number text not null,
  person_name text not null,
  person_type text,
  interviewer text,
  interview_date text,
  location text,
  statement text not null,
  follow_up text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.timeline (
  id uuid primary key default gen_random_uuid(),
  case_number text not null,
  event_time text not null,
  event_title text not null,
  recorded_by text,
  details text not null,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  case_number text not null,
  title text not null,
  report_type text,
  author_name text,
  report_date text,
  content text not null,
  conclusion text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Turn on RLS and explicitly limit table access.
alter table public.profiles enable row level security;
alter table public.cases enable row level security;
alter table public.evidence enable row level security;
alter table public.interviews enable row level security;
alter table public.timeline enable row level security;
alter table public.reports enable row level security;

revoke all on public.profiles, public.cases, public.evidence, public.interviews, public.timeline, public.reports from anon;
grant select, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.cases, public.evidence, public.interviews, public.timeline, public.reports to authenticated;

-- Profiles: members can read their own profile; admins can manage all profiles.
drop policy if exists profiles_read_self_or_admin on public.profiles;
create policy profiles_read_self_or_admin on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select public.is_admin()));
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles for update to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));
drop policy if exists profiles_admin_delete on public.profiles;
create policy profiles_admin_delete on public.profiles for delete to authenticated
using ((select public.is_admin()));

-- Shared roleplay records: approved users read; detectives/admins write.
do $$
declare t text;
begin
  foreach t in array array['cases','evidence','interviews','timeline','reports'] loop
    execute format('drop policy if exists %I on public.%I', t||'_read_approved', t);
    execute format('create policy %I on public.%I for select to authenticated using ((select public.is_approved_member()))', t||'_read_approved', t);
    execute format('drop policy if exists %I on public.%I', t||'_insert_editors', t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select public.my_role()) in (''admin'',''detective''))', t||'_insert_editors', t);
    execute format('drop policy if exists %I on public.%I', t||'_update_editors', t);
    execute format('create policy %I on public.%I for update to authenticated using ((select public.my_role()) in (''admin'',''detective'')) with check ((select public.my_role()) in (''admin'',''detective''))', t||'_update_editors', t);
    execute format('drop policy if exists %I on public.%I', t||'_delete_editors', t);
    execute format('create policy %I on public.%I for delete to authenticated using ((select public.my_role()) in (''admin'',''detective''))', t||'_delete_editors', t);
  end loop;
end $$;

-- Keep updated_at current.
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
do $$
declare t text;
begin
  foreach t in array array['cases','evidence','interviews','timeline','reports'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format('create trigger set_updated_at before update on public.%I for each row execute procedure public.set_updated_at()', t);
  end loop;
end $$;

-- First admin setup:
-- 1) Register your own account in the website.
-- 2) Find its user UUID under Supabase > Authentication > Users.
-- 3) Run this statement after replacing UUID:
-- update public.profiles set approved = true, role = 'admin' where id = 'YOUR-AUTH-USER-UUID';
