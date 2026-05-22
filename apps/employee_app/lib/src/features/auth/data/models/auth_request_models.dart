class EmployeePasswordLoginRequest {
  const EmployeePasswordLoginRequest({
    required this.employeeId,
    required this.password,
  });

  final String employeeId;
  final String password;

  Map<String, dynamic> toJson() => {
    'employeeId': employeeId,
    'password': password,
  };
}

class OtpVerificationRequest {
  const OtpVerificationRequest({required this.phoneNumber, required this.otp});

  final String phoneNumber;
  final String otp;

  Map<String, dynamic> toJson() => {'phoneNumber': phoneNumber, 'otp': otp};
}
