import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 45),
      headers: const {'Accept': 'application/json'},
      validateStatus: (status) {
        // Accept all status codes to handle them manually
        return status != null;
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        print(
          '[DioClient] Request: ${options.method} ${options.baseUrl}${options.path}',
        );
        handler.next(options);
      },
      onError: (error, handler) {
        print('[DioClient] Error: ${error.type} - ${error.message}');
        if (error.type == DioExceptionType.connectionTimeout) {
          print('[DioClient] Connection timeout - backend may be unreachable');
        } else if (error.type == DioExceptionType.receiveTimeout) {
          print('[DioClient] Receive timeout - backend not responding');
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
