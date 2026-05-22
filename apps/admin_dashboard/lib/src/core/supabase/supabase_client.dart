import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientBootstrap {
  static const _defaultSupabaseUrl = 'https://hradcfvcrdkegupeiyff.supabase.co';
  static const _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhyYWRjZnZjcmRrZWd1cGVpeWZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxMjM4NTEsImV4cCI6MjA5NDY5OTg1MX0.Ay6XUM0ro2M0S4REngyUYt_v6r98n1NNWJvFESFB41o';

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultSupabaseUrl,
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultSupabaseAnonKey,
  );

  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        '[Supabase] SUPABASE_URL or SUPABASE_ANON_KEY not provided. Skipping initialization.',
      );
      return;
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    debugPrint('[Supabase] Initialized');
  }
}

SupabaseClient get supabase {
  if (!SupabaseClientBootstrap.isConfigured) {
    throw StateError(
      'Supabase is not configured. Run Flutter with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  return Supabase.instance.client;
}
