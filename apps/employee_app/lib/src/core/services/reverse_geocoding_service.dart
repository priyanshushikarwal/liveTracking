import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reverseGeocodingServiceProvider = Provider<ReverseGeocodingService>((
  ref,
) {
  return ReverseGeocodingService();
});

class ReverseGeocodingService {
  ReverseGeocodingService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {'User-Agent': 'DoonInfra-LiveTracking/1.0'},
            ),
          );

  final Dio _dio;
  final Map<String, String> _cache = {};

  Future<String> resolve({
    required double latitude,
    required double longitude,
    String? fallbackName,
  }) async {
    final key =
        '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': latitude,
          'lon': longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
      );
      final data = response.data ?? const {};
      final address = Map<String, dynamic>.from(data['address'] as Map? ?? {});
      final resolved = _humanName(data, address);
      _cache[key] = resolved;
      return resolved;
    } catch (_) {
      final fallback = fallbackName?.trim();
      final resolved = fallback != null && fallback.isNotEmpty
          ? fallback
          : 'Verified field location';
      _cache[key] = resolved;
      return resolved;
    }
  }

  String _humanName(Map<String, dynamic> data, Map<String, dynamic> address) {
    final building =
        address['building'] ??
        address['office'] ??
        address['commercial'] ??
        data['name'];
    final locality =
        address['suburb'] ??
        address['neighbourhood'] ??
        address['quarter'] ??
        address['road'];
    final city =
        address['city'] ??
        address['town'] ??
        address['municipality'] ??
        address['state_district'];

    final parts = <String>[
      if (building != null && '$building'.trim().isNotEmpty) '$building',
      if (locality != null && '$locality'.trim().isNotEmpty) '$locality',
      if (city != null && '$city'.trim().isNotEmpty) '$city',
    ];

    if (parts.isEmpty) return 'Verified field location';
    return parts.take(3).join(', ');
  }
}
