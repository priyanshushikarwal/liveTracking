-- Public signup requests land in profiles as PENDING until approved in Table Editor.

create unique index if not exists profiles_auth_user_id_key
on public.profiles (auth_user_id);

alter table public.profiles
alter column status set default 'PENDING';

create or replace function public.on_auth_user_insert()
returns trigger
language plpgsql
security definer
as $$
declare
  requested_name text;
  requested_phone text;
  requested_app text;
begin
  requested_name := new.raw_user_meta_data ->> 'full_name';
  requested_phone := new.raw_user_meta_data ->> 'phone';
  requested_app := new.raw_user_meta_data ->> 'requested_app';

  insert into public.profiles (
    auth_user_id,
    role,
    full_name,
    email,
    phone,
    employee_id,
    status,
    meta,
    created_at
  )
  values (
    new.id,
    'EMPLOYEE',
    requested_name,
    new.email,
    requested_phone,
    public.generate_employee_id(),
    'PENDING',
    jsonb_build_object('requested_app', requested_app),
    now()
  )
  on conflict (auth_user_id) do update
  set
    email = excluded.email,
    full_name = coalesce(public.profiles.full_name, excluded.full_name),
    phone = coalesce(public.profiles.phone, excluded.phone),
    meta = coalesce(public.profiles.meta, '{}'::jsonb) || excluded.meta,
    updated_at = now();

  return new;
end;
$$;
