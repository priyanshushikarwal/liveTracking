import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../app/employee_app.dart';
import '../core/config/app_config.dart';
import '../core/services/background_tracking_service.dart';
import '../core/supabase/supabase_client.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientBootstrap.initialize();
  await Hive.initFlutter();
  if (!AppConfig.useDemoMode) {
    await BackgroundTrackingService().initializeBackgroundTrackingService();
  }
  runApp(const ProviderScope(child: EmployeeApp()));
}
