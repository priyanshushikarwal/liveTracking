import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/geo_utils.dart';
import 'location_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return const SecurityService();
});

class SecurityService {
  const SecurityService();

  SecurityEvaluation evaluateLocationIntegrity({
    required LocationSnapshot? previous,
    required LocationSnapshot current,
  }) {
    if (AppConfig.useDemoMode) {
      return const SecurityEvaluation(isTrusted: true, reasons: []);
    }

    final reasons = <String>[];
    if (current.isMocked) {
      reasons.add('Mock location detected on the device.');
    }

    if (previous != null) {
      final meters = GeoUtils.distanceMeters(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      final seconds = max(
        1,
        current.timestamp.difference(previous.timestamp).inSeconds,
      );
      final speedKmh = (meters / seconds) * 3.6;
      if (speedKmh > 160) {
        reasons.add('Suspicious travel speed detected.');
      }
      if (meters > 10000 && seconds < 120) {
        reasons.add('GPS jump detected.');
      }
    }

    return SecurityEvaluation(isTrusted: reasons.isEmpty, reasons: reasons);
  }
}

class SecurityEvaluation {
  const SecurityEvaluation({required this.isTrusted, required this.reasons});

  final bool isTrusted;
  final List<String> reasons;
}
