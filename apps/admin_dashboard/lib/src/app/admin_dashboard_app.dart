import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/theme/admin_theme.dart';

class AdminDashboardApp extends ConsumerWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LiveTrack Admin Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeModeProvider),
      theme: AdminTheme.lightTheme,
      darkTheme: AdminTheme.darkTheme,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
