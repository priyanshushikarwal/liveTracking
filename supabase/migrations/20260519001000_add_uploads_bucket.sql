-- Add the storage bucket used by the Flutter apps for media uploads.
insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do nothing;
