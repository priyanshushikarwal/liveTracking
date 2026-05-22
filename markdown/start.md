Supabase-first workflow (current):

1. Apply Supabase schema

Run the SQL in `supabase/schema.sql` inside the Supabase SQL editor or via migrations.

2. Configure Supabase env values

Get `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase project and pass them to the Flutter apps using `--dart-define`.

3. Run the employee app

```bash
cd apps/employee_app
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

4. Run the admin dashboard

```bash
cd apps/admin_dashboard
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

5. Realtime & Storage

- Employee app writes `live_locations`, `attendance`, and media directly to Supabase Storage and tables.
- Admin dashboard subscribes to realtime changes in `live_locations`, `attendance`, `notifications`, etc.

Notes: Use Supabase Edge Functions for server-side automation if needed. The legacy backend has been removed.