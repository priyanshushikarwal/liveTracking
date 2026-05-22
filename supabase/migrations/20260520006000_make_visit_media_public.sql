-- Visit photos are stored with public_url values and rendered directly by the
-- admin dashboard. Keep the bucket public so those URLs load in Flutter Web.
update storage.buckets
set public = true
where id = 'visit-media';
