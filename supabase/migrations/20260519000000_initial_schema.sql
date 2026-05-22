-- Supabase schema for DoonInfra Field Forces
-- Apply in Supabase SQL editor or migration files

create extension if not exists "pgcrypto";

-- =====================
-- ENUM TYPES
-- =====================

do $$ begin
  create type public.user_role as enum ('EMPLOYEE', 'HR', 'ADMIN', 'SUPER_ADMIN');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.employee_status as enum ('ACTIVE', 'INACTIVE', 'SUSPENDED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.attendance_status as enum ('CHECKED_IN', 'CHECKED_OUT', 'MISSED_CHECKOUT', 'REJECTED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.visit_status as enum ('ASSIGNED', 'STARTED', 'COMPLETED', 'CANCELLED', 'VERIFIED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.alert_type as enum ('FAKE_GPS', 'OFFLINE', 'SOS', 'LATE_ATTENDANCE', 'MISSED_CHECKOUT', 'MISSED_VISIT', 'SECURITY');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.notification_channel as enum ('PUSH', 'EMAIL', 'SMS', 'IN_APP');
exception when duplicate_object then null; end $$;

-- =====================
-- CORE TABLES
-- =====================

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  timezone text not null default 'Asia/Kolkata',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  city text not null,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  name text not null,
  code text unique,
  manager_employee_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id),
  team_id uuid references public.teams(id),
  employee_code text not null unique,
  full_name text not null,
  email text unique,
  phone_number text unique,
  role public.user_role not null default 'EMPLOYEE',
  status public.employee_status not null default 'ACTIVE',
  department text not null,
  designation text not null,
  photo_url text,
  device_binding_id text,
  last_known_lat double precision,
  last_known_lng double precision,
  last_sync_at timestamptz,
  battery_percent integer,
  internet_status text,
  current_activity text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  check_in_at timestamptz not null,
  check_out_at timestamptz,
  latitude double precision not null,
  longitude double precision not null,
  check_out_latitude double precision,
  check_out_longitude double precision,
  site_name text not null,
  selfie_url text,
  notes text,
  shift_start_at timestamptz,
  shift_end_at timestamptz,
  late_minutes integer not null default 0,
  is_fake_gps_suspected boolean not null default false,
  status public.attendance_status not null default 'CHECKED_IN',
  readable_location text,
  check_out_readable_location text,
  confidence_score integer not null default 0,
  gps_accuracy double precision,
  check_out_gps_accuracy double precision,
  device_metadata jsonb,
  check_out_device_metadata jsonb,
  internet_type text,
  attendance_method text not null default 'SELFIE_GEO_VERIFIED',
  check_in_selfie_url text,
  check_out_selfie_url text,
  check_out_notes text,
  work_duration_minutes integer,
  distance_travelled_meters double precision,
  total_visits integer,
  productivity_score integer,
  verification_history jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.visits (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  client_id uuid,
  client_name text not null,
  site_name text not null,
  site_address text not null,
  start_lat double precision not null,
  start_lng double precision not null,
  end_lat double precision,
  end_lng double precision,
  started_at timestamptz,
  scheduled_at timestamptz not null default now(),
  ended_at timestamptz,
  notes text,
  status public.visit_status not null default 'ASSIGNED',
  image_url text,
  verification_qr text,
  verified_at timestamptz,
  verification_distance double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.live_locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  accuracy double precision,
  speed double precision,
  bearing double precision,
  battery_percent integer,
  internet_status text,
  activity text,
  is_mocked boolean not null default false,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.location_history (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  route_id uuid,
  latitude double precision not null,
  longitude double precision not null,
  accuracy double precision,
  speed double precision,
  distance_meters double precision not null default 0,
  activity text,
  is_mocked boolean not null default false,
  battery_percent integer,
  internet_status text,
  recorded_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete cascade,
  type public.alert_type not null,
  title text not null,
  message text not null,
  severity text not null default 'medium',
  metadata jsonb,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  body text not null,
  channel public.notification_channel not null default 'IN_APP',
  audience_role public.user_role,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.productivity_scores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  score integer not null default 0,
  score_date date not null default current_date,
  breakdown jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  actor_user_id uuid,
  actor_role public.user_role,
  action text not null,
  entity_name text not null,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

-- =====================
-- INDEXES
-- =====================

create index if not exists idx_branches_organization_city on public.branches(organization_id, city);
create index if not exists idx_teams_organization_code on public.teams(organization_id, code);
create index if not exists idx_employees_organization_department on public.employees(organization_id, department);
create index if not exists idx_employees_team_id on public.employees(team_id);
create index if not exists idx_employees_status_sync on public.employees(status, last_sync_at);
create index if not exists idx_attendance_employee_checkin on public.attendance(employee_id, check_in_at desc);
create index if not exists idx_attendance_org_checkin on public.attendance(organization_id, check_in_at desc);
create index if not exists idx_visits_employee_scheduled on public.visits(employee_id, scheduled_at desc);
create index if not exists idx_live_locations_org_recorded on public.live_locations(organization_id, recorded_at desc);
create index if not exists idx_live_locations_employee_recorded on public.live_locations(employee_id, recorded_at desc);
create index if not exists idx_location_history_employee_recorded on public.location_history(employee_id, recorded_at desc);
create index if not exists idx_alerts_type_created on public.alerts(type, created_at desc);
create index if not exists idx_notifications_org_created on public.notifications(organization_id, created_at desc);
create index if not exists idx_productivity_scores_employee_date on public.productivity_scores(employee_id, score_date desc);

-- =====================
-- HELPERS
-- =====================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.get_user_role()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'role', 'EMPLOYEE');
$$;

create or replace function public.get_organization_id()
returns uuid
language sql
stable
as $$
  select nullif(auth.jwt() ->> 'organization_id', '')::uuid;
$$;

-- =====================
-- TRIGGERS
-- =====================

drop trigger if exists trg_organizations_updated_at on public.organizations;
create trigger trg_organizations_updated_at before update on public.organizations
for each row execute function public.set_updated_at();

drop trigger if exists trg_branches_updated_at on public.branches;
create trigger trg_branches_updated_at before update on public.branches
for each row execute function public.set_updated_at();

drop trigger if exists trg_teams_updated_at on public.teams;
create trigger trg_teams_updated_at before update on public.teams
for each row execute function public.set_updated_at();

drop trigger if exists trg_employees_updated_at on public.employees;
create trigger trg_employees_updated_at before update on public.employees
for each row execute function public.set_updated_at();

drop trigger if exists trg_attendance_updated_at on public.attendance;
create trigger trg_attendance_updated_at before update on public.attendance
for each row execute function public.set_updated_at();

drop trigger if exists trg_visits_updated_at on public.visits;
create trigger trg_visits_updated_at before update on public.visits
for each row execute function public.set_updated_at();

drop trigger if exists trg_live_locations_updated_at on public.live_locations;
create trigger trg_live_locations_updated_at before update on public.live_locations
for each row execute function public.set_updated_at();

drop trigger if exists trg_productivity_scores_updated_at on public.productivity_scores;
create trigger trg_productivity_scores_updated_at before update on public.productivity_scores
for each row execute function public.set_updated_at();

-- =====================
-- ROW LEVEL SECURITY
-- =====================

alter table public.organizations enable row level security;
alter table public.branches enable row level security;
alter table public.teams enable row level security;
alter table public.employees enable row level security;
alter table public.attendance enable row level security;
alter table public.visits enable row level security;
alter table public.live_locations enable row level security;
alter table public.location_history enable row level security;
alter table public.alerts enable row level security;
alter table public.notifications enable row level security;
alter table public.productivity_scores enable row level security;
alter table public.audit_logs enable row level security;

-- =====================
-- RLS POLICIES
-- =====================

-- Organizations
create policy "org_select_own" on public.organizations
for select using (
  get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR')
  and id = get_organization_id()
);

create policy "org_admin_manage" on public.organizations
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN'))
with check (get_user_role() in ('ADMIN', 'SUPER_ADMIN'));

-- Branches
create policy "branches_select_org" on public.branches
for select using (organization_id = get_organization_id());
create policy "branches_admin_write" on public.branches
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN'))
with check (get_user_role() in ('ADMIN', 'SUPER_ADMIN') and organization_id = get_organization_id());

-- Teams
create policy "teams_select_org" on public.teams
for select using (organization_id = get_organization_id());
create policy "teams_admin_write" on public.teams
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN'))
with check (get_user_role() in ('ADMIN', 'SUPER_ADMIN'));

-- Employees
create policy "employees_select_org" on public.employees
for select using (organization_id = get_organization_id());
create policy "employees_self_update" on public.employees
for update using (id = nullif(auth.jwt() ->> 'sub', '')::uuid)
with check (id = nullif(auth.jwt() ->> 'sub', '')::uuid);
create policy "employees_admin_write" on public.employees
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Attendance
create policy "attendance_select_org" on public.attendance
for select using (organization_id = get_organization_id());
create policy "attendance_employee_insert" on public.attendance
for insert with check (
  employee_id = nullif(auth.jwt() ->> 'sub', '')::uuid
  and organization_id = get_organization_id()
);
create policy "attendance_employee_update_self" on public.attendance
for update using (
  employee_id = nullif(auth.jwt() ->> 'sub', '')::uuid
  and organization_id = get_organization_id()
);
create policy "attendance_admin_manage" on public.attendance
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Visits
create policy "visits_select_org" on public.visits
for select using (organization_id = get_organization_id());
create policy "visits_employee_write_self" on public.visits
for all using (employee_id = nullif(auth.jwt() ->> 'sub', '')::uuid)
with check (organization_id = get_organization_id());
create policy "visits_admin_manage" on public.visits
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Live locations
create policy "live_locations_select_org" on public.live_locations
for select using (organization_id = get_organization_id());
create policy "live_locations_employee_insert" on public.live_locations
for insert with check (
  employee_id = nullif(auth.jwt() ->> 'sub', '')::uuid
  and organization_id = get_organization_id()
);
create policy "live_locations_admin_manage" on public.live_locations
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Location history
create policy "location_history_select_org" on public.location_history
for select using (organization_id = get_organization_id());
create policy "location_history_employee_insert" on public.location_history
for insert with check (
  employee_id = nullif(auth.jwt() ->> 'sub', '')::uuid
  and organization_id = get_organization_id()
);
create policy "location_history_admin_manage" on public.location_history
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Alerts
create policy "alerts_select_org" on public.alerts
for select using (organization_id = get_organization_id());
create policy "alerts_admin_manage" on public.alerts
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Notifications
create policy "notifications_select_org" on public.notifications
for select using (organization_id = get_organization_id());
create policy "notifications_admin_manage" on public.notifications
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Productivity scores
create policy "scores_select_org" on public.productivity_scores
for select using (organization_id = get_organization_id());
create policy "scores_admin_manage" on public.productivity_scores
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN', 'HR'))
with check (organization_id = get_organization_id());

-- Audit logs
create policy "audit_select_org" on public.audit_logs
for select using (organization_id = get_organization_id());
create policy "audit_admin_manage" on public.audit_logs
for all using (get_user_role() in ('ADMIN', 'SUPER_ADMIN'))
with check (organization_id = get_organization_id());

-- =====================
-- STORAGE BUCKETS
-- =====================

insert into storage.buckets (id, name, public)
values
  ('attendance-media', 'attendance-media', false),
  ('visit-media', 'visit-media', false),
  ('profile-images', 'profile-images', false)
on conflict (id) do nothing;

