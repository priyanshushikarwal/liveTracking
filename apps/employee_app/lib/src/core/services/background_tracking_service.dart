import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';

final backgroundTrackingServiceProvider = Provider<BackgroundTrackingService>((
  ref,
) {
  return BackgroundTrackingService();
});

class BackgroundTrackingService {
  BackgroundTrackingService() {
    unawaited(_restoreState());
  }

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _enabled = false;
  bool _configured = false;
  DateTime? _startedAt;

  Future<void> _restoreState() async {
    final storage = const FlutterSecureStorage();
    final raw = await storage.read(key: AppConstants.secureTrackingEnabledKey);
    _enabled = raw == 'true';
  }

  Future<void> start() async {
    // In demo mode we avoid starting the platform background service
    if (AppConfig.useDemoMode) {
      final storage = const FlutterSecureStorage();
      await storage.write(
        key: AppConstants.secureTrackingEnabledKey,
        value: 'true',
      );
      _enabled = true;
      _startedAt = DateTime.now();
      return;
    }

    await initializeBackgroundTrackingService();
    final storage = const FlutterSecureStorage();
    await storage.write(
      key: AppConstants.secureTrackingEnabledKey,
      value: 'true',
    );
    _enabled = true;
    _startedAt = DateTime.now();
    final running = await _service.isRunning();
    if (!running) {
      await _service.startService();
      _service.invoke('setAsForeground');
      _service.invoke('tracking:setEnabled', {'enabled': true});
    } else {
      _service.invoke('tracking:setEnabled', {'enabled': true});
      _service.invoke('setAsForeground');
    }
  }

  Future<void> stop() async {
    final storage = const FlutterSecureStorage();
    await storage.write(
      key: AppConstants.secureTrackingEnabledKey,
      value: 'false',
    );
    _enabled = false;
    if (AppConfig.useDemoMode) return;
    _service.invoke('tracking:setEnabled', {'enabled': false});
    _service.invoke('stopService');
  }

  bool get isEnabled => _enabled;
  DateTime? get startedAt => _startedAt;

  Future<void> initializeBackgroundTrackingService() async {
    if (_configured) {
      return;
    }

    if (AppConfig.useDemoMode) {
      // don't configure the platform background service in demo mode
      _configured = true;
      return;
    }

    WidgetsFlutterBinding.ensureInitialized();
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _backgroundTrackingEntryPoint,
        autoStart: false,
        isForegroundMode: false,
        notificationChannelId: 'live_tracking_background',
        initialNotificationTitle: 'Live tracking ready',
        initialNotificationContent:
            'Background tracking will start when enabled.',
        foregroundServiceNotificationId: 9042,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _backgroundTrackingEntryPoint,
        onBackground: _onIosBackground,
      ),
    );
    _configured = true;
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void _backgroundTrackingEntryPoint(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final storage = const FlutterSecureStorage();
  var enabled =
      await storage.read(key: AppConstants.secureTrackingEnabledKey) == 'true';
  TrackingBackgroundLoop? loop;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('tracking:setEnabled').listen((event) async {
    enabled = event?['enabled'] == true;
    await storage.write(
      key: AppConstants.secureTrackingEnabledKey,
      value: enabled ? 'true' : 'false',
    );

    if (enabled) {
      loop ??= TrackingBackgroundLoop(service: service);
      unawaited(loop!.start());
    } else {
      await loop?.stop();
      loop = null;
    }
  });

  service.on('stopService').listen((_) async {
    await loop?.stop();
    loop = null;
    service.stopSelf();
  });

  if (enabled) {
    loop = TrackingBackgroundLoop(service: service);
    await loop!.start();
  }
}

class TrackingBackgroundLoop {
  TrackingBackgroundLoop({required ServiceInstance service})
    : _service = service;

  final ServiceInstance _service;
  final _battery = Battery();
  final _connectivity = Connectivity();
  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: const {'Accept': 'application/json'},
    ),
  );

  Timer? _timer;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;

  Future<void> start() async {
    _timer?.cancel();
    await _tick();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_tick());
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      final token = await const FlutterSecureStorage().read(
        key: AppConstants.secureTokenKey,
      );
      if (token == null || token.isEmpty) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );

      if (!_shouldSend(position)) {
        return;
      }

      final batteryPercent = await _battery.batteryLevel;
      final connectivity = await _connectivity.checkConnectivity();
      final internetStatus = _label(connectivity);
      final activity = _resolveActivity(position);

      await _dio.post(
        '/tracking/ingest',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'bearing': position.heading,
          'batteryPercent': batteryPercent,
          'internetStatus': internetStatus,
          'recordedAt': position.timestamp.toIso8601String(),
          'activity': activity,
          'isMocked': position.isMocked,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      _lastSentPosition = position;
      _lastSentAt = DateTime.now();
      if (_service is AndroidServiceInstance) {
        _service.setForegroundNotificationInfo(
          title: 'Live tracking active',
          content:
              '${activity == 'MOVING' ? 'Moving' : 'Idle'} • ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        );
      }
    } catch (_) {
      // Background service keeps retrying on next cycle.
    }
  }

  bool _shouldSend(Position position) {
    final now = DateTime.now();
    if (_lastSentPosition == null || _lastSentAt == null) {
      return true;
    }

    final elapsed = now.difference(_lastSentAt!);
    final moving = position.speed >= 1.2;
    final interval = moving
        ? const Duration(seconds: 8)
        : const Duration(seconds: 45);

    final distance = Geolocator.distanceBetween(
      _lastSentPosition!.latitude,
      _lastSentPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    return elapsed >= interval || distance >= (moving ? 15 : 8);
  }

  String _resolveActivity(Position position) {
    return position.speed >= 1.2 ? 'MOVING' : 'IDLE';
  }

  String _label(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
    if (results.contains(ConnectivityResult.mobile)) return 'Mobile Data';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN';
    return 'Offline';
  }
}
