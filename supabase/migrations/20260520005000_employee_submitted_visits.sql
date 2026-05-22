-- Allow employees to create field visits directly from the mobile app.
-- Admins still see the submitted notes, photos and GPS location in realtime.

drop policy if exists visits_employee_insert_profile on public.visits;

create policy visits_employee_insert_profile on public.visits
for insert
with check (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);
