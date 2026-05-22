#!/usr/bin/env bash
set -euo pipefail

echo "LiveTracking — Supabase setup helper"

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required. Install Node.js/npm and try again." >&2
  exit 1
fi

if ! npx supabase --version >/dev/null 2>&1; then
  echo "supabase CLI (via npx) not found. Run 'npx supabase --help' to verify installation." >&2
  exit 1
fi

if [ -z "${PROJECT_REF:-}" ]; then
  echo "ERROR: Please set PROJECT_REF environment variable to your Supabase project ref." >&2
  echo "You can get it from the Supabase dashboard or run: npx supabase projects list" >&2
  echo "Example: PROJECT_REF=abc123 ./scripts/supabase_setup.sh" >&2
  exit 1
fi

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "ERROR: Please set SUPABASE_DB_URL to your project's Postgres connection string." >&2
  echo "Get it from Supabase Dashboard → Settings → Database → Connection string (Postgres)." >&2
  echo "Example: SUPABASE_DB_URL=postgres://... PROJECT_REF=abc123 ./scripts/supabase_setup.sh" >&2
  exit 1
fi

SQL_FILE="supabase/schema.sql"
if [ ! -f "$SQL_FILE" ]; then
  echo "ERROR: $SQL_FILE not found in repository." >&2
  exit 1
fi

echo "Applying SQL schema from $SQL_FILE to database..."
psql "$SUPABASE_DB_URL" -f "$SQL_FILE"

echo "Creating storage bucket 'uploads' (public). If it exists, the command may fail harmlessly." 
# create bucket; --public flag may vary by CLI version
npx supabase storage bucket create uploads --project-ref "$PROJECT_REF" --public || echo "bucket create returned non-zero (it may already exist)"

POLICIES_FILE="supabase/policies_suggested.sql"
cat > "$POLICIES_FILE" <<'SQL'
-- Suggested RLS policies for LiveTracking tables. Review and customize before applying.
-- Example: allow authenticated users to insert/select/update their own attendance rows.
-- Replace `attendance.user_id` below with the actual column that stores the user's uid (e.g., employee_id).

-- Enable RLS for tables (only enable if intended)
-- ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "attendance_owner_full" ON attendance
--   USING (user_id = auth.uid())
--   WITH CHECK (user_id = auth.uid());

-- Similar pattern for visits and live_locations.
-- ALTER TABLE visits ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "visits_owner_full" ON visits
--   USING (user_id = auth.uid())
--   WITH CHECK (user_id = auth.uid());

-- ALTER TABLE live_locations ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "live_locations_insert" ON live_locations
--   FOR INSERT USING (true) WITH CHECK (true);
-- (You may restrict selects to org/staff roles as needed.)

SQL

echo "Wrote suggested RLS SQL to $POLICIES_FILE. Review and apply with psql if you want to enable policies."

echo "Finished. Next steps:"
echo "  1) Verify schema and data in Supabase dashboard (Database → Tables)."
echo "  2) Review $POLICIES_FILE and apply needed RLS policies using psql:"
echo "     psql \"$SUPABASE_DB_URL\" -f $POLICIES_FILE"
echo "  3) Ensure you set the following env vars when running the Flutter apps:"
echo "     SUPABASE_URL (from Project Settings → API)"
echo "     SUPABASE_ANON_KEY (from Project Settings → API)"

echo "Example run (macOS/Linux):"
echo "  PROJECT_REF=your_ref SUPABASE_DB_URL=postgres://... SUPABASE_URL=https://your.supabase.co SUPABASE_ANON_KEY=anon_key ./scripts/supabase_setup.sh"

exit 0
