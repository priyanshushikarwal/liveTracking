-- Make attendance RLS match the employee app's profile-based identity model.
-- The Flutter app writes attendance.employee_id = profiles.id, while older
-- policies compared attendance.employee_id directly with auth.uid().

alter table public.attendance
drop constraint if exists attendance_employee_id_fkey;

alter table public.attendance
alter column organization_id drop not null;

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

create or replace function public.current_profile_status()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.status
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

grant execute on function public.current_profile_id() to authenticated;
grant execute on function public.current_profile_status() to authenticated;
grant execute on function public.current_profile_role() to authenticated;
grant execute on function public.current_profile_org_id() to authenticated;

drop policy if exists "attendance_select_org" on public.attendance;
drop policy if exists "attendance_employee_insert" on public.attendance;
drop policy if exists "attendance_employee_update_self" on public.attendance;
drop policy if exists "attendance_admin_manage" on public.attendance;
drop policy if exists attendance_profile_select_self on public.attendance;
drop policy if exists attendance_profile_insert_self on public.attendance;
drop policy if exists attendance_profile_update_self on public.attendance;
drop policy if exists attendance_admin_select_profiles on public.attendance;
drop policy if exists attendance_admin_manage_profiles on public.attendance;

create policy attendance_profile_select_self on public.attendance
for select
using (employee_id = public.current_profile_id());

create policy attendance_profile_insert_self on public.attendance
for insert
with check (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
  and (
    organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

create policy attendance_profile_update_self on public.attendance
for update
using (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
)
with check (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
  and (
    organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

create policy attendance_admin_select_profiles on public.attendance
for select
using (
  lower(coalesce(public.current_profile_role(), '')) in ('super_admin', 'admin', 'manager', 'hr')
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

create policy attendance_admin_manage_profiles on public.attendance
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
