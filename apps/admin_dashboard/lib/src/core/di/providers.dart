import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/live_tracking/presentation/pages/live_tracking_page.dart';
import '../../features/live_tracking/presentation/viewmodels/live_tracking_view_model.dart';
import '../supabase/supabase_client.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/visits/presentation/pages/visits_page.dart';

// Auth stub provider
final adminAuthViewModelProvider =
    StateNotifierProvider<AdminAuthViewModel, AdminAuthState>((ref) {
      return AdminAuthViewModel();
    });

final liveTrackingViewModelProvider =
    StateNotifierProvider<LiveTrackingViewModel, LiveTrackingState>((ref) {
      return LiveTrackingViewModel(supabase: supabase);
    });

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark);

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const AdminSignUpPage(),
      ),
      GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => const LiveTrackingPage(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendancePage(),
      ),
      GoRoute(path: '/visits', builder: (context, state) => const VisitsPage()),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const EmployeesPage(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
