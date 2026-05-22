-- Align attendance writes with the Flutter profile-based auth flow.
-- Employee/mobile app writes attendance.employee_id = profiles.id.

alter table public.attendance
drop constraint if exists attendance_employee_id_fkey;

alter table public.attendance
alter column organization_id drop not null;

drop policy if exists attendance_profile_select_self on public.attendance;
create policy attendance_profile_select_self on public.attendance
for select using (
  exists (
    select 1
    from public.profiles p
    where p.auth_user_id = auth.uid()
      and p.id = public.attendance.employee_id
  )
);

drop policy if exists attendance_profile_insert_self on public.attendance;
create policy attendance_profile_insert_self on public.attendance
for insert with check (
  exists (
    select 1
    from public.profiles p
    where p.auth_user_id = auth.uid()
      and p.id = public.attendance.employee_id
      and lower(p.role) = 'employee'
      and lower(p.status) = 'active'
  )
);

drop policy if exists attendance_profile_update_self on public.attendance;
create policy attendance_profile_update_self on public.attendance
for update using (
  exists (
    select 1
    from public.profiles p
    where p.auth_user_id = auth.uid()
      and p.id = public.attendance.employee_id
      and lower(p.role) = 'employee'
      and lower(p.status) = 'active'
  )
);

drop policy if exists attendance_admin_select_profiles on public.attendance;
create policy attendance_admin_select_profiles on public.attendance
for select using (
  exists (
    select 1
    from public.profiles p
    where p.auth_user_id = auth.uid()
      and lower(p.role) in ('super_admin', 'admin', 'manager')
      and lower(p.status) = 'active'
  )
);
