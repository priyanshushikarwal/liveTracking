-- Enterprise client visit management upgrade.
-- Keeps the existing visits table and extends it for assigned, scheduled,
-- geo-verified client visits using the profile-based employee identity.

alter type public.visit_status add value if not exists 'MISSED';
alter type public.visit_status add value if not exists 'RESCHEDULED';

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  company_name text not null,
  client_type text not null default 'Enterprise',
  contact_person text,
  phone text,
  email text,
  address text,
  latitude double precision,
  longitude double precision,
  category text not null default 'General',
  status text not null default 'ACTIVE',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.visits drop constraint if exists visits_employee_id_fkey;
alter table public.visits alter column employee_id drop not null;
alter table public.visits alter column organization_id drop not null;
alter table public.visits alter column start_lat drop not null;
alter table public.visits alter column start_lng drop not null;

alter table public.visits add column if not exists assigned_by uuid;
alter table public.visits add column if not exists assigned_by_name text;
alter table public.visits add column if not exists contact_person text;
alter table public.visits add column if not exists phone text;
alter table public.visits add column if not exists email text;
alter table public.visits add column if not exists visit_type text not null default 'Client Visit';
alter table public.visits add column if not exists priority text not null default 'MEDIUM';
alter table public.visits add column if not exists objective text not null default 'Client meeting';
alter table public.visits add column if not exists client_lat double precision;
alter table public.visits add column if not exists client_lng double precision;
alter table public.visits add column if not exists allowed_radius_meters double precision not null default 120;
alter table public.visits add column if not exists gps_accuracy double precision;
alter table public.visits add column if not exists battery_percent integer;
alter table public.visits add column if not exists network_type text;
alter table public.visits add column if not exists device_metadata jsonb not null default '{}'::jsonb;
alter table public.visits add column if not exists outcome text;
alter table public.visits add column if not exists productivity_score integer not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'visits_client_id_fkey'
      and conrelid = 'public.visits'::regclass
  ) then
    alter table public.visits
      add constraint visits_client_id_fkey
      foreign key (client_id)
      references public.clients(id)
      on delete set null
      not valid;
  end if;
end $$;

create table if not exists public.visit_photos (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  category text not null default 'Other',
  storage_path text not null,
  public_url text,
  latitude double precision,
  longitude double precision,
  readable_location text,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.visit_notes (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  note text not null,
  note_format text not null default 'plain_text',
  is_draft boolean not null default false,
  created_by uuid default public.current_profile_id(),
  created_at timestamptz not null default now()
);

create table if not exists public.visit_documents (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  document_type text not null default 'Customer Document',
  title text,
  storage_path text not null,
  public_url text,
  uploaded_by uuid default public.current_profile_id(),
  created_at timestamptz not null default now()
);

create table if not exists public.visit_audio_notes (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  title text not null default 'Voice note',
  storage_path text not null,
  public_url text,
  duration_seconds integer,
  recorded_by uuid default public.current_profile_id(),
  created_at timestamptz not null default now()
);

create table if not exists public.visit_signatures (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  storage_path text not null,
  public_url text,
  signed_by_name text,
  signed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.visit_followups (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  followup_date timestamptz not null,
  priority text not null default 'MEDIUM',
  notes text,
  assigned_employee_id uuid,
  generated_visit_id uuid references public.visits(id) on delete set null,
  create_followup_visit boolean not null default true,
  completed_at timestamptz,
  created_by uuid default public.current_profile_id(),
  created_at timestamptz not null default now()
);

create table if not exists public.visit_activities (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  activity_type text not null,
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid default public.current_profile_id(),
  created_at timestamptz not null default now()
);

create table if not exists public.visit_outcomes (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  outcome text not null,
  notes text,
  created_by uuid default public.current_profile_id(),
  created_at timestamptz not null default now()
);

create index if not exists idx_clients_org on public.clients(organization_id, company_name);
create index if not exists idx_visits_employee_status on public.visits(employee_id, status, scheduled_at);
create index if not exists idx_visit_photos_visit on public.visit_photos(visit_id);
create index if not exists idx_visit_notes_visit on public.visit_notes(visit_id);
create index if not exists idx_visit_documents_visit on public.visit_documents(visit_id);
create index if not exists idx_visit_audio_visit on public.visit_audio_notes(visit_id);
create index if not exists idx_visit_signatures_visit on public.visit_signatures(visit_id);
create index if not exists idx_visit_followups_visit on public.visit_followups(visit_id, followup_date);
create index if not exists idx_visit_activities_visit on public.visit_activities(visit_id, created_at desc);
create index if not exists idx_visit_outcomes_visit on public.visit_outcomes(visit_id);

create or replace function public.calculate_visit_productivity_score(
  p_duration_minutes integer,
  p_outcome text,
  p_photo_count integer,
  p_notes text,
  p_followup_count integer
)
returns integer
language plpgsql
immutable
as $$
declare
  score integer := 35;
begin
  if p_duration_minutes between 10 and 240 then
    score := score + 15;
  end if;
  if lower(coalesce(p_outcome, '')) in (
    'interested',
    'quotation sent',
    'installation approved',
    'installation completed',
    'issue resolved',
    'service completed'
  ) then
    score := score + 25;
  elsif lower(coalesce(p_outcome, '')) = 'follow-up required' then
    score := score + 15;
  end if;
  score := score + least(coalesce(p_photo_count, 0) * 5, 15);
  if length(coalesce(p_notes, '')) >= 40 then
    score := score + 10;
  end if;
  if coalesce(p_followup_count, 0) > 0 then
    score := score + 5;
  end if;
  return greatest(0, least(score, 100));
end;
$$;

create or replace function public.sync_visit_completion_score()
returns trigger
language plpgsql
as $$
declare
  duration_minutes integer;
  photo_count integer;
  followup_count integer;
begin
  if new.status in ('COMPLETED', 'VERIFIED') and new.started_at is not null and new.ended_at is not null then
    duration_minutes := extract(epoch from (new.ended_at - new.started_at)) / 60;
    select count(*) into photo_count from public.visit_photos where visit_id = new.id;
    select count(*) into followup_count from public.visit_followups where visit_id = new.id;
    new.productivity_score := public.calculate_visit_productivity_score(
      duration_minutes,
      new.outcome,
      photo_count,
      new.notes,
      followup_count
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_visit_completion_score on public.visits;
create trigger trg_sync_visit_completion_score
before update on public.visits
for each row execute function public.sync_visit_completion_score();

create or replace function public.create_visit_from_followup()
returns trigger
language plpgsql
as $$
declare
  parent_visit public.visits%rowtype;
begin
  if new.create_followup_visit is false or new.generated_visit_id is not null then
    return new;
  end if;
  select * into parent_visit from public.visits where id = new.visit_id;
  if parent_visit.id is null then
    return new;
  end if;
  insert into public.visits (
    organization_id,
    employee_id,
    client_id,
    client_name,
    site_name,
    site_address,
    scheduled_at,
    priority,
    objective,
    visit_type,
    client_lat,
    client_lng,
    allowed_radius_meters,
    status
  )
  values (
    parent_visit.organization_id,
    coalesce(new.assigned_employee_id, parent_visit.employee_id),
    parent_visit.client_id,
    parent_visit.client_name,
    parent_visit.site_name,
    parent_visit.site_address,
    new.followup_date,
    new.priority,
    coalesce(new.notes, 'Follow-up visit'),
    'Follow-up',
    parent_visit.client_lat,
    parent_visit.client_lng,
    parent_visit.allowed_radius_meters,
    'ASSIGNED'
  )
  returning id into new.generated_visit_id;
  return new;
end;
$$;

drop trigger if exists trg_create_visit_from_followup on public.visit_followups;
create trigger trg_create_visit_from_followup
before insert on public.visit_followups
for each row execute function public.create_visit_from_followup();

insert into storage.buckets (id, name, public)
values ('visit-media', 'visit-media', false)
on conflict (id) do nothing;

alter table public.clients enable row level security;
alter table public.visits enable row level security;
alter table public.visit_photos enable row level security;
alter table public.visit_notes enable row level security;
alter table public.visit_documents enable row level security;
alter table public.visit_audio_notes enable row level security;
alter table public.visit_signatures enable row level security;
alter table public.visit_followups enable row level security;
alter table public.visit_activities enable row level security;
alter table public.visit_outcomes enable row level security;

drop policy if exists clients_select_org on public.clients;
drop policy if exists clients_admin_manage on public.clients;
create policy clients_select_org on public.clients
for select using (
  public.is_admin_like()
  or organization_id = public.current_profile_org_id()
  or organization_id is null
);
create policy clients_admin_manage on public.clients
for all using (public.is_admin_like())
with check (
  public.current_profile_org_id() is null
  or organization_id is null
  or organization_id = public.current_profile_org_id()
);

drop policy if exists "visits_select_org" on public.visits;
drop policy if exists "visits_employee_write_self" on public.visits;
drop policy if exists "visits_admin_manage" on public.visits;
drop policy if exists visits_employee_select_profile on public.visits;
drop policy if exists visits_employee_update_profile on public.visits;
drop policy if exists visits_admin_manage_profiles on public.visits;

create policy visits_employee_select_profile on public.visits
for select using (employee_id = public.current_profile_id());

create policy visits_employee_update_profile on public.visits
for update using (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_role(), '')) = 'employee'
)
with check (
  employee_id = public.current_profile_id()
  and lower(coalesce(public.current_profile_status(), '')) = 'active'
);

create policy visits_admin_manage_profiles on public.visits
for all using (
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

create or replace function public.visit_actor_can_access(p_visit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.visits v
    where v.id = p_visit_id
      and (
        v.employee_id = public.current_profile_id()
        or (
          public.is_admin_like()
          and (
            public.current_profile_org_id() is null
            or v.organization_id is null
            or v.organization_id = public.current_profile_org_id()
          )
        )
      )
  );
$$;

grant execute on function public.visit_actor_can_access(uuid) to authenticated;
grant execute on function public.calculate_visit_productivity_score(integer, text, integer, text, integer) to authenticated;

drop policy if exists visit_photos_access on public.visit_photos;
drop policy if exists visit_notes_access on public.visit_notes;
drop policy if exists visit_documents_access on public.visit_documents;
drop policy if exists visit_audio_notes_access on public.visit_audio_notes;
drop policy if exists visit_signatures_access on public.visit_signatures;
drop policy if exists visit_followups_access on public.visit_followups;
drop policy if exists visit_activities_access on public.visit_activities;
drop policy if exists visit_outcomes_access on public.visit_outcomes;

create policy visit_photos_access on public.visit_photos
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));
create policy visit_notes_access on public.visit_notes
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));
create policy visit_documents_access on public.visit_documents
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));
create policy visit_audio_notes_access on public.visit_audio_notes
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));
create policy visit_signatures_access on public.visit_signatures
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));
create policy visit_followups_access on public.visit_followups
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));
create policy visit_activities_access on public.visit_activities
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));
create policy visit_outcomes_access on public.visit_outcomes
for all using (public.visit_actor_can_access(visit_id))
with check (public.visit_actor_can_access(visit_id));

drop policy if exists visit_media_authenticated_read on storage.objects;
drop policy if exists visit_media_authenticated_write on storage.objects;
create policy visit_media_authenticated_read on storage.objects
for select using (
  bucket_id = 'visit-media'
  and auth.role() = 'authenticated'
);
create policy visit_media_authenticated_write on storage.objects
for insert with check (
  bucket_id = 'visit-media'
  and auth.role() = 'authenticated'
);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'visits',
    'visit_photos',
    'visit_notes',
    'visit_documents',
    'visit_audio_notes',
    'visit_signatures',
    'visit_followups',
    'visit_activities',
    'visit_outcomes'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    exception
      when duplicate_object then null;
      when undefined_object then null;
    end;
  end loop;
end $$;
