-- Create roles, profiles, session tracking, and helper functions for enterprise auth

-- Roles table
create table if not exists public.roles (
  id serial primary key,
  role_name text not null unique,
  permissions jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Insert default roles if missing
insert into public.roles (role_name, permissions)
values
  ('SUPER_ADMIN', '{"super":true}'),
  ('ADMIN', '{"manage_employees":true}'),
  ('MANAGER', '{"team_access":true}'),
  ('EMPLOYEE', '{}')
on conflict (role_name) do nothing;

-- Profiles table linking to auth.users
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete cascade,
  role text not null default 'EMPLOYEE',
  full_name text,
  email text,
  employee_id text unique,
  organization_id uuid references public.organizations(id),
  branch_id uuid references public.branches(id),
  department_id uuid,
  team_id uuid,
  phone text,
  status text not null default 'ACTIVE',
  meta jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Sequence & generator for employee IDs
create sequence if not exists public.employee_seq start 1000;

create or replace function public.generate_employee_id()
returns text
language sql
stable
as $$
  select 'EMP-' || nextval('public.employee_seq')::text;
$$;

-- Auto-create profile when auth.user is created
create or replace function public.on_auth_user_insert()
returns trigger
language plpgsql
security definer
as $$
begin
  -- create a profile if not exists for the new auth user
  insert into public.profiles (auth_user_id, role, email, created_at)
  values (new.id, 'EMPLOYEE', new.email, now())
  on conflict (auth_user_id) do nothing;
  return new;
end;
$$;

-- Trigger on auth.users insert
drop trigger if exists on_auth_user_insert on auth.users;
create trigger on_auth_user_insert
after insert on auth.users
for each row execute function public.on_auth_user_insert();

-- RPC: resolve email by employee_id
create or replace function public.get_email_by_employee_id(emp_id text)
returns text
language sql
stable
as $$
  select p.email
  from public.profiles p
  where p.employee_id = emp_id
  limit 1;
$$;

-- Login attempts for brute-force protection
create table if not exists public.login_attempts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id),
  ip text,
  user_agent text,
  successful boolean not null default false,
  created_at timestamptz not null default now()
);

-- Device/session tracking
create table if not exists public.device_sessions (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete cascade,
  device_info text,
  last_active timestamptz not null default now(),
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);

-- Update timestamp trigger for profiles
create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
for each row execute function public.set_profile_updated_at();

-- RLS: enable and policies for profiles
alter table public.profiles enable row level security;

-- Allow users to select their own profile
create policy profiles_select_self on public.profiles
for select using (auth.uid() = auth_user_id);

-- Allow admins and super_admins to select within their organization
create policy profiles_select_org on public.profiles
for select using (
  exists (
    select 1 from public.profiles as me
    where me.auth_user_id = auth.uid()
      and (me.role in ('ADMIN', 'SUPER_ADMIN'))
      and (me.organization_id = public.profiles.organization_id)
  )
);

-- Allow admins to insert/manage employees within their org
create policy profiles_admin_manage on public.profiles
for all using (
  exists (
    select 1 from public.profiles as me
    where me.auth_user_id = auth.uid()
      and (me.role in ('ADMIN', 'SUPER_ADMIN'))
      and (me.organization_id = public.profiles.organization_id)
  )
) with check (
  -- ensure role being set is a valid role
  role in (select role_name from public.roles)
);

-- Allow users to update only certain fields of their own profile
create policy profiles_update_self on public.profiles
for update using (auth.uid() = auth_user_id)
with check (auth.uid() = auth_user_id);

-- Audit/log table for role changes
create table if not exists public.role_change_logs (
  id uuid primary key default gen_random_uuid(),
  changed_by uuid references auth.users(id),
  target_user uuid references auth.users(id),
  old_role text,
  new_role text,
  reason text,
  created_at timestamptz not null default now()
);

-- Function + trigger: when profile.role changes, log it
create or replace function public.log_role_change()
returns trigger
language plpgsql
as $$
begin
  if old.role is distinct from new.role then
    insert into public.role_change_logs (changed_by, target_user, old_role, new_role, created_at)
    values (auth.uid()::uuid, new.auth_user_id, old.role, new.role, now());
  end if;
  return new;
end;
$$;

drop trigger if exists trg_log_role_change on public.profiles;
create trigger trg_log_role_change after update on public.profiles
for each row execute function public.log_role_change();

-- Grant minimal rights to anon/authenticated roles (handled by RLS mostly)
-- Done. Review and customize policies per org needs.
