import 'dart:math';

class GeoUtils {
  const GeoUtils._();

  static double distanceMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(endLat - startLat);
    final dLng = _degToRad(endLng - startLng);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(startLat)) *
            cos(_degToRad(endLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static bool withinRadius({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required double allowedMeters,
  }) {
    return distanceMeters(startLat, startLng, endLat, endLng) <= allowedMeters;
  }

  static double _degToRad(double degrees) => degrees * pi / 180;
}
