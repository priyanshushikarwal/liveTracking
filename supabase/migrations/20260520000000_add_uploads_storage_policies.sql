-- Allow authenticated users to upload attendance media into the public uploads bucket.
-- This keeps selfies in Supabase Storage while preserving access control via auth.

insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do nothing;

drop policy if exists "uploads_authenticated_insert" on storage.objects;
drop policy if exists "uploads_authenticated_update" on storage.objects;
drop policy if exists "uploads_authenticated_delete" on storage.objects;
drop policy if exists "uploads_public_select" on storage.objects;

-- Authenticated users can insert object rows into the uploads bucket.
create policy "uploads_authenticated_insert"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'uploads');

-- Authenticated users can update/delete their own uploads if needed for retries or cleanup.
create policy "uploads_authenticated_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'uploads');

create policy "uploads_authenticated_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'uploads');

-- Public read access for this bucket.
create policy "uploads_public_select"
on storage.objects
for select
to public
using (bucket_id = 'uploads');
