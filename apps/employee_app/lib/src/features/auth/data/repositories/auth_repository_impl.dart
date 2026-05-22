import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_request_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorage,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorage = secureStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  @override
  Future<UserSession> loginWithEmployeeId({
    required String employeeId,
    required String password,
  }) async {
    final session = await _remoteDataSource.loginWithEmployeeId(
      EmployeePasswordLoginRequest(employeeId: employeeId, password: password),
    );
    await _persistSession(session);
    return session;
  }

  @override
  Future<void> logout() => _secureStorage.clearSession();

  @override
  Future<void> requestOtp(String phoneNumber) {
    return _remoteDataSource.requestOtp(phoneNumber);
  }

  @override
  Future<UserSession> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final session = await _remoteDataSource.verifyOtp(
      OtpVerificationRequest(phoneNumber: phoneNumber, otp: otp),
    );
    await _persistSession(session);
    return session;
  }

  Future<void> _persistSession(UserSession session) {
    return _secureStorage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      deviceBindingId: session.deviceBindingId,
      session: session,
    );
  }

  @override
  Future<UserSession?> readPersistedSession() {
    return _secureStorage.readSession();
  }
}
