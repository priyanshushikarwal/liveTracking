import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/models/employee_profile.dart';
import '../../domain/entities/user_session.dart';
import '../models/auth_request_models.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<UserSession> loginWithEmployeeId(
    EmployeePasswordLoginRequest request,
  ) async {
    if (AppConfig.useDemoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return _demoSession(
        employeeId: request.employeeId,
        phoneNumber: '+91 9876543210',
      );
    }

    final response = await _dio.post(
      '/auth/employee/login',
      data: {
        'employeeCode': request.employeeId,
        'password': request.password,
        'deviceId': 'mobile-${request.employeeId}',
      },
    );
    return _parseSession(response.data, fallbackEmployeeId: request.employeeId);
  }

  Future<void> requestOtp(String phoneNumber) async {
    if (AppConfig.useDemoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }
    await _dio.post('/auth/otp/request', data: {'phoneNumber': phoneNumber});
  }

  Future<UserSession> verifyOtp(OtpVerificationRequest request) async {
    if (AppConfig.useDemoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return _demoSession(
        employeeId: 'EMP-2048',
        phoneNumber: request.phoneNumber,
      );
    }

    final response = await _dio.post(
      '/auth/otp/verify',
      data: request.toJson(),
    );
    return _parseSession(
      response.data,
      fallbackPhoneNumber: request.phoneNumber,
    );
  }

  UserSession _demoSession({
    required String employeeId,
    required String phoneNumber,
  }) {
    return UserSession(
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
      deviceBindingId: 'device-binding-001',
      employee: EmployeeProfile(
        id: employeeId,
        name: 'Aarav Mehta',
        phone: phoneNumber,
        designation: 'Field Sales Executive',
        department: 'North Zone',
        organizationId: 'demo-org',
      ),
    );
  }

  UserSession _parseSession(
    dynamic data, {
    String fallbackEmployeeId = 'EMP-2048',
    String fallbackPhoneNumber = '+91 9876543210',
  }) {
    final payload = Map<String, dynamic>.from(data as Map? ?? const {});
    final employee = Map<String, dynamic>.from(
      payload['employee'] as Map? ?? const {},
    );

    return UserSession(
      accessToken: payload['accessToken'] as String? ?? '',
      refreshToken: payload['refreshToken'] as String? ?? '',
      deviceBindingId:
          payload['deviceBindingId'] as String? ?? 'device-binding-001',
      employee: EmployeeProfile(
        id:
            (employee['employeeCode'] as String?) ??
            (employee['id'] as String?) ??
            fallbackEmployeeId,
        name: employee['name'] as String? ?? 'Employee',
        phone: employee['phone'] as String? ?? fallbackPhoneNumber,
        designation: employee['designation'] as String? ?? 'Field Executive',
        department: employee['department'] as String? ?? 'Operations',
        organizationId: employee['organizationId'] as String? ?? '',
      ),
    );
  }
}
