import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

class LocationService {
  const LocationService();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<LocationSnapshot> currentLocation() async {
    final serviceEnabled = await isServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException('Location services are turned off.');
    }

    final permission = await ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationServiceException('Location permission is denied.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    return _toSnapshot(position);
  }

  Stream<LocationSnapshot> locationStream() async* {
    final permission = await ensurePermission();
    final serviceEnabled = await isServiceEnabled();
    if (!serviceEnabled ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission or GPS service is unavailable.',
      );
    }

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).map(_toSnapshot);
  }

  LocationSnapshot _toSnapshot(Position position) {
    return LocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      speed: position.speed,
      heading: position.heading,
      isMocked: position.isMocked,
    );
  }
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.speed,
    required this.heading,
    required this.isMocked,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final double speed;
  final double heading;
  final bool isMocked;
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;
}
