import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession?> readPersistedSession();

  Future<UserSession> loginWithEmployeeId({
    required String employeeId,
    required String password,
  });

  Future<void> requestOtp(String phoneNumber);

  Future<UserSession> verifyOtp({
    required String phoneNumber,
    required String otp,
  });

  Future<void> logout();
}
