import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/admin_dashboard_app.dart';
import '../core/supabase/supabase_client.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientBootstrap.initialize();
  runApp(const ProviderScope(child: AdminDashboardApp()));
}
