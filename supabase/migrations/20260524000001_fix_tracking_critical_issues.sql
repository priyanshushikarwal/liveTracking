-- =============================================================================
-- CRITICAL TRACKING DATABASE FIX
-- =============================================================================
-- Issue 1: Schema mismatch - location_history missing bearing column
-- Issue 2: RLS policies missing employee SELECT and UPDATE permissions
-- Issue 3: Foreign key constraints point to wrong table (employees vs profiles)
-- =============================================================================

-- =============================================================================
-- PART 1: SCHEMA FIXES
-- =============================================================================

-- Tracking payloads currently sent by the Flutter apps:
--
-- live_locations foreground/background:
--   employee_id, organization_id, latitude, longitude, accuracy, speed, bearing,
--   battery_percent, internet_status, recorded_at, activity, is_mocked,
--   employee_name, tracking_status, network_status, timestamp
--
-- location_history foreground:
--   employee_id, organization_id, latitude, longitude, accuracy, speed,
--   battery_percent, internet_status, recorded_at, activity, is_mocked
--
-- location_history background:
--   employee_id, organization_id, latitude, longitude, accuracy, speed, bearing,
--   battery_percent, internet_status, recorded_at, activity, is_mocked,
--   employee_name, tracking_status, network_status, timestamp

-- Add bearing column to location_history (exists in live_locations but not history)
alter table public.location_history
add column if not exists bearing double precision;

-- Verify/Add compatibility columns that code sends
alter table public.live_locations
add column if not exists employee_name text,
add column if not exists tracking_status text,
add column if not exists network_status text,
add column if not exists timestamp timestamptz;

alter table public.location_history
add column if not exists employee_name text,
add column if not exists tracking_status text,
add column if not exists network_status text,
add column if not exists timestamp timestamptz;

-- Backfill any null compatibility columns from base columns
update public.live_locations
set
  tracking_status = coalesce(tracking_status, activity),
  network_status = coalesce(network_status, internet_status),
  timestamp = coalesce(timestamp, recorded_at)
where tracking_status is null
   or network_status is null
   or timestamp is null;

update public.location_history
set
  tracking_status = coalesce(tracking_status, activity),
  network_status = coalesce(network_status, internet_status),
  timestamp = coalesce(timestamp, recorded_at)
where tracking_status is null
   or network_status is null
   or timestamp is null;

-- =============================================================================
-- PART 2: FOREIGN KEY CONSTRAINT FIX
-- =============================================================================

-- The Flutter app sends employee_id = profiles.id (not employees.id)
-- We need to either:
-- Option A: Drop the FK constraints (profiles.id is not a foreign key to anything)
-- Option B: Change tracking to use employees.id (requires code change)

-- We choose Option A because:
-- 1. The app already resolves profiles.id from auth
-- 2. The profiles table is the source of truth for the employee app
-- 3. The employees table is a separate entity for admin management

-- Drop existing FK constraints that point to employees table
alter table public.live_locations
drop constraint if exists live_locations_employee_id_fkey;

alter table public.location_history
drop constraint if exists location_history_employee_id_fkey;

-- Note: We do NOT add FK constraints to profiles.id because:
-- 1. profiles.id is a primary key, not a foreign key
-- 2. The relationship is auth_user_id -> profiles.id
-- 3. Tracking just needs the profile ID, not a strict FK constraint

-- Make organization_id nullable to allow flexible inserts
alter table public.live_locations
alter column organization_id drop not null;

alter table public.location_history
alter column organization_id drop not null;

-- =============================================================================
-- PART 3: AUTH/PROFILE IDENTITY HELPERS
-- =============================================================================

-- Tracking records use profiles.id as employee_id. These helpers resolve the
-- authenticated Supabase user to the profile row used by the mobile app.
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

-- =============================================================================
-- PART 4: RLS POLICY FIXES
-- =============================================================================

-- Enable RLS (ensure it's on)
alter table public.live_locations enable row level security;
alter table public.location_history enable row level security;

-- Drop all existing policies on these tables to start clean
drop policy if exists "live_locations_select_org" on public.live_locations;
drop policy if exists "live_locations_employee_insert" on public.live_locations;
drop policy if exists "live_locations_admin_manage" on public.live_locations;
drop policy if exists "live_locations_employee_insert_profile" on public.live_locations;
drop policy if exists "live_locations_admin_select_profiles" on public.live_locations;
drop policy if exists "live_locations_admin_manage_profiles" on public.live_locations;
drop policy if exists "live_locations_employee_select_own" on public.live_locations;
drop policy if exists "live_locations_employee_update_own" on public.live_locations;
drop policy if exists "live_locations_admin_select" on public.live_locations;

drop policy if exists "location_history_select_org" on public.location_history;
drop policy if exists "location_history_employee_insert" on public.location_history;
drop policy if exists "location_history_admin_manage" on public.location_history;
drop policy if exists "location_history_employee_insert_profile" on public.location_history;
drop policy if exists "location_history_admin_select_profiles" on public.location_history;
drop policy if exists "location_history_admin_manage_profiles" on public.location_history;
drop policy if exists "location_history_employee_select_own" on public.location_history;
drop policy if exists "location_history_admin_select" on public.location_history;

-- =============================================================================
-- LIVE_LOCATIONS POLICIES
-- =============================================================================

-- Policy 1: Employee can INSERT their own location
-- The Flutter app sends employee_id = profiles.id
-- We verify the JWT belongs to a profile with that ID

create policy live_locations_employee_insert
on public.live_locations
for insert
with check (
  -- Employee must be active
  lower(coalesce(public.current_profile_status(), '')) = 'active'
  -- Employee app accounts only; admins have separate policies below.
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  -- Must match their own profile ID
  and employee_id = public.current_profile_id()
  -- Organization must match or be null
  and (organization_id is null or organization_id = public.current_profile_org_id())
);

-- Policy 2: Employee can SELECT their own location records
create policy live_locations_employee_select_own
on public.live_locations
for select
using (
  employee_id = public.current_profile_id()
);

-- Policy 3: Employee can UPDATE their own live location (UPSERT pattern)
-- This allows the app to update the existing record instead of creating duplicates
create policy live_locations_employee_update_own
on public.live_locations
for update
using (
  employee_id = public.current_profile_id()
)
with check (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
  and (organization_id is null or organization_id = public.current_profile_org_id())
);

-- Policy 4: Admin can SELECT all records in their organization
create policy live_locations_admin_select
on public.live_locations
for select
using (
  public.is_admin_like()
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

-- Policy 5: Admin can manage (INSERT, UPDATE, DELETE) all records
create policy live_locations_admin_manage
on public.live_locations
for all
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
);

-- =============================================================================
-- LOCATION_HISTORY POLICIES
-- =============================================================================

-- Policy 1: Employee can INSERT their own location history
create policy location_history_employee_insert
on public.location_history
for insert
with check (
  lower(coalesce(public.current_profile_status(), '')) = 'active'
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
  and employee_id = public.current_profile_id()
  and (organization_id is null or organization_id = public.current_profile_org_id())
);

-- Policy 2: Employee can SELECT their own location history
create policy location_history_employee_select_own
on public.location_history
for select
using (
  employee_id = public.current_profile_id()
);

-- Policy 3: Admin can SELECT all location history in their organization
create policy location_history_admin_select
on public.location_history
for select
using (
  public.is_admin_like()
  and (
    public.current_profile_org_id() is null
    or organization_id is null
    or organization_id = public.current_profile_org_id()
  )
);

-- Policy 4: Admin can manage all location history
create policy location_history_admin_manage
on public.location_history
for all
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
);

-- =============================================================================
-- PART 5: REALTIME CONFIGURATION
-- =============================================================================

-- Ensure replica identity is set for realtime subscriptions
alter table public.live_locations replica identity full;
alter table public.location_history replica identity full;

-- Add tables to realtime publication (idempotent)
do $$
begin
  begin
    alter publication supabase_realtime add table public.live_locations;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.location_history;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

-- =============================================================================
-- PART 6: INDEXES FOR PERFORMANCE
-- =============================================================================

-- Indexes for common queries
create index if not exists idx_live_locations_org_recorded
  on public.live_locations(organization_id, recorded_at desc);

create index if not exists idx_live_locations_employee_recorded
  on public.live_locations(employee_id, recorded_at desc);

create index if not exists idx_location_history_employee_recorded
  on public.location_history(employee_id, recorded_at desc);

create index if not exists idx_location_history_org_recorded
  on public.location_history(organization_id, recorded_at desc);

-- =============================================================================
-- VERIFICATION QUERY (Run manually to verify)
-- =============================================================================
/*
-- Check table structures:
select column_name, data_type, is_nullable
from information_schema.columns
where table_name = 'live_locations'
order by ordinal_position;

select column_name, data_type, is_nullable
from information_schema.columns
where table_name = 'location_history'
order by ordinal_position;

-- Check RLS policies:
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where tablename in ('live_locations', 'location_history');

-- Check constraints:
select conname, contype, pg_get_constraintdef(oid)
from pg_constraint
where conrelid in ('live_locations'::regclass, 'location_history'::regclass);

-- Check auth/profile identity chain:
select
  u.id as auth_user_id,
  p.id as profile_id,
  p.employee_id as employee_code,
  p.role,
  p.status,
  p.organization_id
from auth.users u
join public.profiles p on p.auth_user_id = u.id
where lower(p.role) = 'employee'
order by p.created_at desc
limit 20;

-- Employee insert smoke test template:
-- Run this while authenticated as a real employee. It must insert exactly one row.
insert into public.live_locations (
  employee_id, organization_id, latitude, longitude, accuracy, speed, bearing,
  battery_percent, internet_status, recorded_at, activity, is_mocked,
  employee_name, tracking_status, network_status, timestamp
)
values (
  public.current_profile_id(), public.current_profile_org_id(),
  28.4595, 77.0266, 10, 0, 0, 90, 'debug',
  now(), 'DEBUG', false, 'Debug Employee', 'DEBUG', 'debug', now()
)
returning id, employee_id, organization_id, latitude, longitude, recorded_at;

insert into public.location_history (
  employee_id, organization_id, latitude, longitude, accuracy, speed, bearing,
  battery_percent, internet_status, recorded_at, activity, is_mocked,
  employee_name, tracking_status, network_status, timestamp
)
values (
  public.current_profile_id(), public.current_profile_org_id(),
  28.4595, 77.0266, 10, 0, 0, 90, 'debug',
  now(), 'DEBUG', false, 'Debug Employee', 'DEBUG', 'debug', now()
)
returning id, employee_id, organization_id, latitude, longitude, recorded_at;
*/
