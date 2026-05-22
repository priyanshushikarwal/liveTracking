import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

String? dashboardAccessToken;

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (status) {
        // Accept all status codes to handle them manually
        return status != null;
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Dashboard-Client'] = 'flutter-web';
        if (dashboardAccessToken != null) {
          options.headers['Authorization'] = 'Bearer $dashboardAccessToken';
          print('[DioClient] Added auth token to request: ${options.path}');
        } else {
          print(
            '[DioClient] No auth token available for request: ${options.path}',
          );
        }
        print(
          '[DioClient] Request: ${options.method} ${options.baseUrl}${options.path}',
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        print(
          '[DioClient] Response ${response.statusCode}: ${response.requestOptions.path}',
        );
        handler.next(response);
      },
      onError: (error, handler) {
        print('[DioClient] Error ${error.type}: ${error.message}');
        print('[DioClient] Error response: ${error.response?.data}');
        handler.next(error);
      },
    ),
  );

  return dio;
});
