-- Ensure employee-captured visit proof photos can be uploaded and displayed.
insert into storage.buckets (id, name, public)
values ('visit-media', 'visit-media', true)
on conflict (id) do update set public = true;

drop policy if exists visit_media_authenticated_read on storage.objects;
drop policy if exists visit_media_authenticated_write on storage.objects;
drop policy if exists visit_media_authenticated_update on storage.objects;
drop policy if exists visit_media_authenticated_delete on storage.objects;

create policy visit_media_authenticated_read on storage.objects
for select
to authenticated
using (bucket_id = 'visit-media');

create policy visit_media_authenticated_write on storage.objects
for insert
to authenticated
with check (bucket_id = 'visit-media');

create policy visit_media_authenticated_update on storage.objects
for update
to authenticated
using (bucket_id = 'visit-media')
with check (bucket_id = 'visit-media');

create policy visit_media_authenticated_delete on storage.objects
for delete
to authenticated
using (bucket_id = 'visit-media');
