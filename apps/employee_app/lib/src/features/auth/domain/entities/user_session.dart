import '../../../../shared/models/employee_profile.dart';

class UserSession {
  const UserSession({
    required this.accessToken,
    required this.refreshToken,
    required this.deviceBindingId,
    required this.employee,
  });

  final String accessToken;
  final String refreshToken;
  final String deviceBindingId;
  final EmployeeProfile employee;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'deviceBindingId': deviceBindingId,
      'employee': employee.toJson(),
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      deviceBindingId: json['deviceBindingId'] as String? ?? '',
      employee: EmployeeProfile.fromJson(
        Map<String, dynamic>.from(json['employee'] as Map? ?? const {}),
      ),
    );
  }
}
