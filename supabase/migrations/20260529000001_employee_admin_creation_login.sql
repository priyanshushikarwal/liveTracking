-- Make admin-created employee credentials usable from the mobile login screen.
-- The employee app resolves EMP-* to an email before authentication, so this
-- function must bypass profile RLS while only returning the email field.

create or replace function public.get_email_by_employee_id(emp_id text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.email
  from public.profiles p
  where upper(p.employee_id) = upper(emp_id)
    and lower(p.role) = 'employee'
    and lower(p.status) = 'active'
  limit 1;
$$;

grant execute on function public.get_email_by_employee_id(text) to anon;
grant execute on function public.get_email_by_employee_id(text) to authenticated;

create or replace function public.generate_employee_id()
returns text
language sql
volatile
security definer
set search_path = public
as $$
  select 'EMP-' || nextval('public.employee_seq')::text;
$$;

grant execute on function public.generate_employee_id() to authenticated;

create or replace function public.admin_list_employee_profiles()
returns table (
  id uuid,
  full_name text,
  employee_id text,
  department_id uuid,
  role text,
  status text,
  meta jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.full_name,
    p.employee_id,
    p.department_id,
    p.role,
    p.status,
    p.meta
  from public.profiles p
  where public.is_admin_like()
    and lower(p.role) = 'employee'
    and (
      public.current_profile_org_id() is null
      or p.organization_id is null
      or p.organization_id = public.current_profile_org_id()
    )
  order by p.full_name nulls last, p.created_at desc;
$$;

grant execute on function public.admin_list_employee_profiles() to authenticated;
