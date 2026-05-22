import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/supabase/supabase_client.dart' as sb;
import '../../../../shared/models/employee_profile.dart';
import '../../domain/entities/user_session.dart';

class AuthState {
  const AuthState({
    this.loading = false,
    this.restoring = false,
    this.phoneNumber = '',
    this.session,
    this.profile,
    this.error,
  });

  final bool loading;
  final bool restoring;
  final String phoneNumber;
  final dynamic session;
  final Map<String, dynamic>? profile;
  final String? error;

  AuthState copyWith({
    bool? loading,
    bool? restoring,
    String? phoneNumber,
    dynamic session,
    Map<String, dynamic>? profile,
    String? error,
    bool clearSession = false,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      restoring: restoring ?? this.restoring,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      session: clearSession ? null : session ?? this.session,
      profile: clearProfile ? null : profile ?? this.profile,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AuthViewModel extends StateNotifier<AuthState> {
  AuthViewModel(dynamic ref) : super(const AuthState());

  Future<void> loginWithEmployeeId(String employeeId, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final SupabaseClient supabase = sb.supabase;
      final loginId = employeeId.trim();
      String email = loginId;

      if (_looksLikeEmployeeId(loginId)) {
        final resolvedEmail = await supabase.rpc<String?>(
          'get_email_by_employee_id',
          params: {'emp_id': loginId.toUpperCase()},
        );
        if (resolvedEmail == null || resolvedEmail.trim().isEmpty) {
          state = state.copyWith(
            loading: false,
            error: 'Employee ID not found',
          );
          return;
        }
        email = resolvedEmail.trim();
      }

      final authRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = authRes.session;
      final userId = authRes.user?.id ?? session?.user.id;
      if (session == null || userId == null) {
        state = state.copyWith(
          loading: false,
          error: 'Unable to start employee session',
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
          error: 'Employee profile not found',
        );
        return;
      }

      final role = _normalizeRole(profile['role']);
      if (role != 'employee') {
        await supabase.auth.signOut();
        state = state.copyWith(
          loading: false,
          clearSession: true,
          clearProfile: true,
          error: 'This account is not allowed in the employee app',
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

      final employeeSession = UserSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        deviceBindingId: userId,
        employee: EmployeeProfile(
          id: profile['id']?.toString() ?? '',
          name: profile['full_name'] as String? ?? 'Employee',
          phone: profile['phone'] as String? ?? '',
          designation: profile['designation'] as String? ?? 'Field Executive',
          department: profile['department_id']?.toString() ?? 'Operations',
          organizationId: profile['organization_id']?.toString() ?? '',
        ),
      );
      await const SecureStorageService(FlutterSecureStorage()).saveSession(
        accessToken: employeeSession.accessToken,
        refreshToken: employeeSession.refreshToken,
        deviceBindingId: employeeSession.deviceBindingId,
        session: employeeSession,
      );

      state = state.copyWith(
        loading: false,
        session: session,
        profile: profile,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    state = state.copyWith(
      loading: true,
      phoneNumber: phoneNumber,
      clearError: true,
    );
    try {
      final SupabaseClient supabase = sb.supabase;
      await supabase.auth.signInWithOtp(phone: phoneNumber);
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> verifyOtp(String otp) async {
    // OTP verification varies across Supabase SDK versions. Use phone OTP flows via UI and
    // rely on backend auth sign-in methods. For now, this is a placeholder that reads
    // the phone number from state and returns a clear message.
    final phoneNumber = state.phoneNumber;
    if (phoneNumber.isEmpty) {
      state = state.copyWith(
        error: 'No phone number available for OTP verification',
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      error: 'OTP verify not implemented in this client',
    );
  }

  Future<void> logout() async {
    try {
      final SupabaseClient supabase = sb.supabase;
      await supabase.auth.signOut();
      state = state.copyWith(clearSession: true, clearProfile: true);
    } catch (_) {}
  }

  bool _looksLikeEmployeeId(String value) {
    return value.trim().toUpperCase().startsWith('EMP-');
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
