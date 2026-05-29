#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_HOME="${VERCEL_CACHE_DIR:-$HOME/.cache}/flutter-${FLUTTER_VERSION}"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -d "$FLUTTER_HOME/bin" ]; then
    git clone https://github.com/flutter/flutter.git \
      --branch "$FLUTTER_VERSION" \
      --depth 1 \
      "$FLUTTER_HOME"
  fi

  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

flutter config --enable-web
flutter --version

cd apps/admin_dashboard
flutter pub get

build_args=(
  --release
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://hradcfvcrdkegupeiyff.supabase.co}"
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhyYWRjZnZjcmRrZWd1cGVpeWZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxMjM4NTEsImV4cCI6MjA5NDY5OTg1MX0.Ay6XUM0ro2M0S4REngyUYt_v6r98n1NNWJvFESFB41o}"
)

if [ -n "${API_BASE_URL:-}" ]; then
  build_args+=(--dart-define=API_BASE_URL="$API_BASE_URL")
fi

if [ -n "${WEBSOCKET_BASE_URL:-}" ]; then
  build_args+=(--dart-define=WEBSOCKET_BASE_URL="$WEBSOCKET_BASE_URL")
fi

flutter build web "${build_args[@]}"
