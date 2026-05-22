-- Align live tracking tables with the profile-based employee app identity.
-- The Flutter employee app writes employee_id = profiles.id.

create or replace function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(p.role)
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_profile_status()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(p.status)
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
  select coalesce(public.current_profile_role() in ('super_admin', 'admin', 'manager', 'hr'), false);
$$;

grant execute on function public.current_profile_id() to authenticated;
grant execute on function public.current_profile_role() to authenticated;
grant execute on function public.current_profile_status() to authenticated;
grant execute on function public.current_profile_org_id() to authenticated;
grant execute on function public.is_admin_like() to authenticated;

drop policy if exists profiles_select_admin_org on public.profiles;
drop policy if exists profiles_insert_admin_org on public.profiles;
drop policy if exists profiles_update_admin_org on public.profiles;
drop policy if exists profiles_delete_admin_org on public.profiles;

create policy profiles_select_admin_org on public.profiles
for select
using (
  public.is_admin_like()
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

create policy profiles_insert_admin_org on public.profiles
for insert
with check (
  public.is_admin_like()
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
  and lower(role) in ('super_admin', 'admin', 'manager', 'hr', 'employee')
);

create policy profiles_update_admin_org on public.profiles
for update
using (
  public.is_admin_like()
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
)
with check (
  public.is_admin_like()
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
  and lower(role) in ('super_admin', 'admin', 'manager', 'hr', 'employee')
);

create policy profiles_delete_admin_org on public.profiles
for delete
using (
  public.is_admin_like()
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

alter table public.live_locations
drop constraint if exists live_locations_employee_id_fkey;

alter table public.location_history
drop constraint if exists location_history_employee_id_fkey;

alter table public.live_locations
alter column organization_id drop not null;

alter table public.location_history
alter column organization_id drop not null;

drop policy if exists "live_locations_select_org" on public.live_locations;
drop policy if exists "live_locations_employee_insert" on public.live_locations;
drop policy if exists "live_locations_admin_manage" on public.live_locations;
drop policy if exists "location_history_select_org" on public.location_history;
drop policy if exists "location_history_employee_insert" on public.location_history;
drop policy if exists "location_history_admin_manage" on public.location_history;

create policy live_locations_employee_insert_profile on public.live_locations
for insert
with check (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
  and (organization_id is null or organization_id = public.current_profile_org_id())
);

create policy live_locations_admin_select_profiles on public.live_locations
for select
using (
  lower(coalesce(public.current_profile_role(), '')) in ('super_admin', 'admin', 'manager', 'hr')
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

create policy live_locations_admin_manage_profiles on public.live_locations
for all
using (
  lower(coalesce(public.current_profile_role(), '')) in ('super_admin', 'admin', 'hr')
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
)
with check (
  lower(coalesce(public.current_profile_role(), '')) in ('super_admin', 'admin', 'hr')
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

create policy location_history_employee_insert_profile on public.location_history
for insert
with check (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
  and (organization_id is null or organization_id = public.current_profile_org_id())
);

create policy location_history_admin_select_profiles on public.location_history
for select
using (
  lower(coalesce(public.current_profile_role(), '')) in ('super_admin', 'admin', 'manager', 'hr')
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

create policy location_history_admin_manage_profiles on public.location_history
for all
using (
  lower(coalesce(public.current_profile_role(), '')) in ('super_admin', 'admin', 'hr')
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
)
with check (
  lower(coalesce(public.current_profile_role(), '')) in ('super_admin', 'admin', 'hr')
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);
