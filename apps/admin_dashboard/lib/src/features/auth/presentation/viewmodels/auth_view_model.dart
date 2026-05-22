import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_client.dart' as sb;
import '../../domain/entities/admin_session.dart';

class AdminAuthState {
  const AdminAuthState({
    this.loading = false,
    this.session,
    this.profile,
    this.error,
  });

  final bool loading;
  final AdminSession? session;
  final Map<String, dynamic>? profile;
  final String? error;

  AdminAuthState copyWith({
    bool? loading,
    AdminSession? session,
    Map<String, dynamic>? profile,
    String? error,
    bool clearSession = false,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AdminAuthState(
      loading: loading ?? this.loading,
      session: clearSession ? null : session ?? this.session,
      profile: clearProfile ? null : profile ?? this.profile,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AdminAuthViewModel extends StateNotifier<AdminAuthState> {
  AdminAuthViewModel() : super(const AdminAuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final SupabaseClient supabase = sb.supabase;
      final res = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final session = res.session;
      final userId = res.user?.id ?? session?.user.id;
      if (session == null || userId == null) {
        state = state.copyWith(
          loading: false,
          error: 'Unable to start admin session',
        );
        return;
      }

      final profile = await _readProfile(supabase, userId);
      if (profile == null) {
        await supabase.auth.signOut();
        state = state.copyWith(
          loading: false,
          clearSession: true,
          clearProfile: true,
          error: 'Admin profile not found',
        );
        return;
      }

      final role = _normalizeRole(profile['role']);
      if (!{'super_admin', 'admin', 'manager'}.contains(role)) {
        await supabase.auth.signOut();
        state = state.copyWith(
          loading: false,
          clearSession: true,
          clearProfile: true,
          error: 'This account is not allowed in the admin dashboard',
        );
        return;
      }

      if (!_isActiveStatus(profile['status'])) {
        await supabase.auth.signOut();
        state = state.copyWith(
          loading: false,
          clearSession: true,
          clearProfile: true,
          error: 'Your access request is pending approval',
        );
        return;
      }

      state = state.copyWith(
        loading: false,
        session: AdminSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
          role: role,
          name: profile['full_name'] as String? ?? 'Admin',
          organizationId: profile['organization_id']?.toString() ?? '',
        ),
        profile: profile,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    try {
      final SupabaseClient supabase = sb.supabase;
      await supabase.auth.signOut();
      state = state.copyWith(clearSession: true, clearProfile: true);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readProfile(
    SupabaseClient supabase,
    String userId,
  ) async {
    final data = await supabase
        .from('profiles')
        .select(
          'id, auth_user_id, role, full_name, email, employee_id, organization_id, branch_id, department_id, team_id, phone, status',
        )
        .eq('auth_user_id', userId)
        .maybeSingle();

    if (data == null) {
      return null;
    }
    return Map<String, dynamic>.from(data);
  }

  String _normalizeRole(Object? value) {
    return (value?.toString() ?? '').trim().toLowerCase();
  }

  bool _isActiveStatus(Object? value) {
    return (value?.toString() ?? '').trim().toLowerCase() == 'active';
  }
}
