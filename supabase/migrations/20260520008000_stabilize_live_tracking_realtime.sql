-- Stabilize existing live tracking realtime and optional debug/summary fields.
alter table public.live_locations add column if not exists employee_name text;
alter table public.live_locations add column if not exists tracking_status text;
alter table public.live_locations add column if not exists network_status text;
alter table public.live_locations add column if not exists timestamp timestamptz;

alter table public.location_history add column if not exists employee_name text;
alter table public.location_history add column if not exists tracking_status text;
alter table public.location_history add column if not exists network_status text;
alter table public.location_history add column if not exists timestamp timestamptz;

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

alter table public.live_locations replica identity full;
alter table public.location_history replica identity full;
alter table public.visits replica identity full;

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

  begin
    alter publication supabase_realtime add table public.visits;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;
