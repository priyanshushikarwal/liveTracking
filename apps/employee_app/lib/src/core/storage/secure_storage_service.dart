import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import '../../features/auth/domain/entities/user_session.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService(FlutterSecureStorage());
});

class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String deviceBindingId,
    required UserSession session,
  }) async {
    await _storage.write(key: AppConstants.secureTokenKey, value: accessToken);
    await _storage.write(
      key: AppConstants.secureRefreshTokenKey,
      value: refreshToken,
    );
    await _storage.write(
      key: AppConstants.secureDeviceBindingKey,
      value: deviceBindingId,
    );
    await _storage.write(
      key: AppConstants.secureEmployeeSessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<String?> readToken() =>
      _storage.read(key: AppConstants.secureTokenKey);

  Future<UserSession?> readSession() async {
    final rawSession = await _storage.read(
      key: AppConstants.secureEmployeeSessionKey,
    );
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    return UserSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(rawSession) as Map),
    );
  }

  Future<void> clearSession() => _storage.deleteAll();
}
