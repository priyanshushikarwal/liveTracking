-- Fix: infinite recursion in profiles RLS policies (42P17)
-- Root cause: policies on public.profiles were querying public.profiles directly.

-- Helper functions run as definer to avoid recursive RLS evaluation.
create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.role
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_profile_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.organization_id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.is_admin_like()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('ADMIN', 'SUPER_ADMIN', 'MANAGER'), false);
$$;

grant execute on function public.current_profile_role() to authenticated;
grant execute on function public.current_profile_org_id() to authenticated;
grant execute on function public.is_admin_like() to authenticated;

alter table public.profiles enable row level security;

-- Remove old recursive policies.
drop policy if exists profiles_select_self on public.profiles;
drop policy if exists profiles_select_org on public.profiles;
drop policy if exists profiles_admin_manage on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
drop policy if exists profiles_select_admin_org on public.profiles;
drop policy if exists profiles_insert_admin_org on public.profiles;
drop policy if exists profiles_update_admin_org on public.profiles;
drop policy if exists profiles_delete_admin_org on public.profiles;

-- Self access (required for login/session bootstrapping).
create policy profiles_select_self on public.profiles
for select
using (auth.uid() = auth_user_id);

create policy profiles_update_self on public.profiles
for update
using (auth.uid() = auth_user_id)
with check (auth.uid() = auth_user_id);

-- Admin/manager org-scoped access.
create policy profiles_select_admin_org on public.profiles
for select
using (
  public.is_admin_like()
  and public.current_profile_org_id() is not null
  and organization_id = public.current_profile_org_id()
);

create policy profiles_insert_admin_org on public.profiles
for insert
with check (
  public.is_admin_like()
  and public.current_profile_org_id() is not null
  and organization_id = public.current_profile_org_id()
  and role in (select role_name from public.roles)
);

create policy profiles_update_admin_org on public.profiles
for update
using (
  public.is_admin_like()
  and public.current_profile_org_id() is not null
  and organization_id = public.current_profile_org_id()
)
with check (
  public.is_admin_like()
  and public.current_profile_org_id() is not null
  and organization_id = public.current_profile_org_id()
  and role in (select role_name from public.roles)
);

create policy profiles_delete_admin_org on public.profiles
for delete
using (
  public.is_admin_like()
  and public.current_profile_org_id() is not null
  and organization_id = public.current_profile_org_id()
);
