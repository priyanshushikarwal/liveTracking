# Supabase Migration Plan

## Target Architecture

Flutter Employee App -> Supabase -> Flutter Web HR Dashboard

### Supabase Responsibilities
- Authentication for employees and admins
- PostgreSQL database for all domain entities
- Realtime subscriptions for live locations, attendance, notifications
- Storage for selfies, visit images, and profile photos
- Row Level Security for organization isolation
- Edge Functions for validation, analytics, and notification automation

## What Exists Today
- Flutter employee app with Riverpod, GoRouter, Dio, secure storage, offline queue, camera, geolocation, and tracking UI
- Flutter web admin dashboard with Riverpod, GoRouter, dashboard pages, and realtime tracking UI
- Node/Express backend with Prisma, Redis, Docker, and Socket.IO

## Migration Strategy
1. Introduce Supabase client layer in both Flutter apps
2. Replace auth calls with Supabase Auth
3. Replace backend REST calls with Supabase database queries and RPCs
4. Replace Socket.IO with Supabase Realtime subscriptions
5. Replace media upload endpoints with Supabase Storage uploads
6. Apply RLS policies and org-based filtering
7. Retire the Node/Express/Prisma stack after parity is verified

## Immediate Next Deliverables
- Supabase SQL schema
- RLS policies
- Storage bucket setup
- Flutter Supabase service layer
- Repository refactor for auth, attendance, visits, tracking, notifications
- Dashboard realtime subscriptions
- Employee app offline sync bridge to Supabase

## Notes
- This migration should be done incrementally to avoid breaking the existing UI.
- Use a separate Supabase project for development and production environments.
