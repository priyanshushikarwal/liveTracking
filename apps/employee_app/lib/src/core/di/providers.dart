import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/presentation/pages/attendance_page_enhanced.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/attendance/presentation/viewmodels/attendance_view_model.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/camera/presentation/pages/camera_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/live_status/presentation/pages/live_status_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/tracking/presentation/pages/tracking_page.dart';
import '../../features/tracking/presentation/viewmodels/tracking_view_model.dart';
import '../../features/visits/data/repositories/visit_repository_impl.dart';
import '../../features/visits/presentation/pages/visit_page.dart';
import '../../features/visits/presentation/viewmodels/visit_view_model.dart';
// dio removed after migrating to Supabase
import '../storage/offline_queue_service.dart';
import '../services/media_storage_service.dart';
import '../supabase/supabase_client.dart';

// Auth stub provider
final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>((
  ref,
) {
  return AuthViewModel(ref);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    supabaseClient: supabase,
    queueService: ref.watch(offlineQueueProvider),
    mediaStorage: ref.watch(mediaStorageProvider),
  );
});

final visitRepositoryProvider = Provider<VisitRepositoryImpl>((ref) {
  return VisitRepositoryImpl(supabaseClient: supabase);
});

final attendanceViewModelProvider =
    StateNotifierProvider<AttendanceViewModel, AttendanceState>((ref) {
      return AttendanceViewModel(ref);
    });

final visitViewModelProvider =
    StateNotifierProvider<VisitViewModel, VisitState>((ref) {
      return VisitViewModel(ref);
    });

final trackingViewModelProvider =
    StateNotifierProvider<TrackingViewModel, TrackingState>((ref) {
      return TrackingViewModel(ref);
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
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendancePage(),
      ),
      GoRoute(path: '/visits', builder: (context, state) => const VisitPage()),
      GoRoute(path: '/camera', builder: (context, state) => const CameraPage()),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
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
        path: '/live-status',
        builder: (context, state) => const LiveStatusPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/tracking',
        builder: (context, state) => const TrackingPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
