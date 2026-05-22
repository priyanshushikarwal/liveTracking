# DoonInfra Field Forces

Enterprise field force automation workspace with:

- `apps/employee_app`: Flutter mobile app for attendance, visits, live tracking, offline sync, secure camera flow, and analytics.
- `apps/admin_dashboard`: Flutter Web dashboard for HR/admin monitoring, live employee tracking, reports, alerts, and workforce analytics.
- `backend`: Express, Prisma, PostgreSQL, Redis, Socket.IO API.

## Local Run (Supabase-only)

This repository now uses Supabase as the sole backend. There is no local Node.js backend, Docker, Redis, or Prisma runtime required.

1) Create a Supabase project and apply the SQL schema in `supabase/schema.sql` using the Supabase SQL editor.

2) Obtain your **SUPABASE_URL** and **SUPABASE_ANON_KEY** (and optionally the service role key for admin tasks).

3) Run the Flutter apps (pass Supabase config via `--dart-define` or set environment variables):

Employee app:

```bash
cd apps/employee_app
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

Admin dashboard (web/desktop):

```bash
cd apps/admin_dashboard
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

Notes:
- For Android emulators, pass the same `--dart-define` values.
- The apps initialize Supabase at startup and use `supabase_flutter` for auth, realtime, storage, and queries.
- If you need server-side logic, use Supabase Edge Functions instead of a custom Express server.

## Demo Credentials

- Admin: `admin@dooninfra.com` / `admin@123`
- Employee: `EMP-2048` / `password@123`
- OTP: `123456`

## Implemented Architecture

- Clean modular backend with controller, service, repository style boundaries.
- Prisma schema for organizations, branches, teams, admins, employees, clients, attendance, visits, routes, location logs, alerts, notifications, productivity scores, sessions, and activity logs.
- JWT auth, refresh/session persistence, RBAC, Helmet, CORS, rate limiting, request validation, logging, and centralized error middleware.
- Employee mobile app with Riverpod, GoRouter, Dio, secure storage, Hive offline queue, location service, battery/connectivity telemetry, attendance, visits, tracking, splash/login, analytics, notifications, profile/settings/history screens.
- Admin web app with route-gated login, API-backed dashboard summary, live employee tracking list, reports, analytics, attendance, visits, employee, notification, and settings pages.
- Socket.IO realtime tracking updates for admin monitoring.
- Docker Compose for PostgreSQL, Redis, and API.

## External Credentials

All external services are represented in `backend/.env.example`. Add real values later for Google Maps, Firebase messaging, and SSL pinning. The project runs locally with seeded data before those accounts are created.

## API Docs

See [backend/docs/api.md](./backend/docs/api.md).
