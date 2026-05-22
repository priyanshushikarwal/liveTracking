import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/services/background_tracking_service.dart';
import '../../../../core/services/device_status_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/tracking_transport_service.dart';
import '../../../../core/storage/offline_queue_service.dart';

enum TrackingConnectionStatus { connecting, connected, disconnected }

class TrackingState {
  const TrackingState({
    this.loading = false,
    this.trackingEnabled = false,
    this.pendingSyncItems = 0,
    this.lastLocation,
    this.route = const [],
    this.serverRoute = const [],
    this.lastSyncSummary,
    this.error,
    this.gpsEnabled = false,
    this.permissionDenied = false,
    this.connectionStatus = TrackingConnectionStatus.connecting,
    this.internetStatus = 'Checking',
    this.batteryPercent = 0,
    this.followEmployee = true,
    this.serverAcknowledgedAt,
    this.trackingStatus = 'IDLE',
  });

  final bool loading;
  final bool trackingEnabled;
  final int pendingSyncItems;
  final LocationSnapshot? lastLocation;
  final List<LocationSnapshot> route;
  final List<LocationSnapshot> serverRoute;
  final String? lastSyncSummary;
  final String? error;
  final bool gpsEnabled;
  final bool permissionDenied;
  final TrackingConnectionStatus connectionStatus;
  final String internetStatus;
  final int batteryPercent;
  final bool followEmployee;
  final DateTime? serverAcknowledgedAt;
  final String trackingStatus;

  TrackingState copyWith({
    bool? loading,
    bool? trackingEnabled,
    int? pendingSyncItems,
    LocationSnapshot? lastLocation,
    List<LocationSnapshot>? route,
    List<LocationSnapshot>? serverRoute,
    String? lastSyncSummary,
    String? error,
    bool? gpsEnabled,
    bool? permissionDenied,
    TrackingConnectionStatus? connectionStatus,
    String? internetStatus,
    int? batteryPercent,
    bool? followEmployee,
    DateTime? serverAcknowledgedAt,
    String? trackingStatus,
    bool clearError = false,
    bool clearSyncSummary = false,
  }) {
    return TrackingState(
      loading: loading ?? this.loading,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      pendingSyncItems: pendingSyncItems ?? this.pendingSyncItems,
      lastLocation: lastLocation ?? this.lastLocation,
      route: route ?? this.route,
      serverRoute: serverRoute ?? this.serverRoute,
      lastSyncSummary: clearSyncSummary
          ? null
          : lastSyncSummary ?? this.lastSyncSummary,
      error: clearError ? null : error ?? this.error,
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      internetStatus: internetStatus ?? this.internetStatus,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      followEmployee: followEmployee ?? this.followEmployee,
      serverAcknowledgedAt: serverAcknowledgedAt ?? this.serverAcknowledgedAt,
      trackingStatus: trackingStatus ?? this.trackingStatus,
    );
  }
}

class TrackingViewModel extends StateNotifier<TrackingState> {
  TrackingViewModel(this._ref) : super(const TrackingState()) {
    unawaited(initialize());
  }

  final Ref _ref;

  StreamSubscription<LocationSnapshot>? _locationSubscription;
  StreamSubscription<TrackingTransportConnectionState>? _connectionSubscription;
  StreamSubscription<TrackingServerUpdate>? _serverSubscription;
  StreamSubscription<String>? _statusSubscription;
  Timer? _deviceTimer;
  DateTime? _lastPublishedAt;
  LocationSnapshot? _lastPublishedLocation;

  Future<void> initialize() async {
    await _refreshTrackingStatus();
    await _refreshDeviceSnapshot();
    await _refreshLocationCapabilities();
    await _loadInitialLocation();
    await _ref.read(trackingTransportServiceProvider).initialize();
    _bindTransport();
    _startLocationStream();
    _deviceTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refreshDeviceSnapshot()),
    );
  }

  Future<void> _refreshTrackingStatus() async {
    final service = _ref.read(backgroundTrackingServiceProvider);
    final count = await _ref.read(offlineQueueProvider).pendingCount();
    state = state.copyWith(
      trackingEnabled: service.isEnabled,
      pendingSyncItems: count,
    );
  }

  Future<void> _refreshLocationCapabilities() async {
    final locationService = _ref.read(locationServiceProvider);
    final gpsEnabled = await locationService.isServiceEnabled();
    final permission = await locationService.ensurePermission();
    state = state.copyWith(
      gpsEnabled: gpsEnabled,
      permissionDenied:
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever,
    );
  }

  Future<void> _refreshDeviceSnapshot() async {
    final device = await _ref.read(deviceStatusServiceProvider).snapshot();
    if (!mounted) return;
    state = state.copyWith(
      batteryPercent: device.batteryPercent,
      internetStatus: device.internetStatus,
    );
  }

  Future<void> _loadInitialLocation() async {
    try {
      final location = await _ref
          .read(locationServiceProvider)
          .currentLocation();
      if (!mounted) return;
      state = state.copyWith(
        lastLocation: location,
        route: _appendRoutePoint(state.route, location),
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(error: '$error');
    }
  }

  void _bindTransport() {
    final transport = _ref.read(trackingTransportServiceProvider);
    _connectionSubscription?.cancel();
    _serverSubscription?.cancel();
    _statusSubscription?.cancel();

    _connectionSubscription = transport.connectionStream.listen((connection) {
      if (!mounted) return;
      state = state.copyWith(
        connectionStatus: switch (connection) {
          TrackingTransportConnectionState.connecting =>
            TrackingConnectionStatus.connecting,
          TrackingTransportConnectionState.connected =>
            TrackingConnectionStatus.connected,
          TrackingTransportConnectionState.disconnected =>
            TrackingConnectionStatus.disconnected,
        },
      );
    });

    _serverSubscription = transport.serverUpdateStream.listen((event) async {
      final serverPoint = LocationSnapshot(
        latitude: event.latitude,
        longitude: event.longitude,
        accuracy: event.accuracy,
        timestamp: event.recordedAt,
        speed: event.speed,
        heading: event.heading,
        isMocked: false,
      );
      final count = await _ref.read(offlineQueueProvider).pendingCount();
      if (!mounted) return;
      state = state.copyWith(
        serverRoute: _appendRoutePoint(state.serverRoute, serverPoint),
        serverAcknowledgedAt: event.recordedAt,
        pendingSyncItems: count,
        trackingStatus: event.trackingStatus,
        lastSyncSummary: event.isOnline
            ? 'Realtime update acknowledged.'
            : 'Tracker connected but employee marked offline.',
        clearError: true,
      );
    });

    _statusSubscription = transport.statusStream.listen((status) {
      if (!mounted) return;
      state = state.copyWith(trackingStatus: status);
    });
  }

  void _startLocationStream() {
    _locationSubscription?.cancel();
    _locationSubscription = _ref
        .read(locationServiceProvider)
        .locationStream()
        .listen(_handleLocationUpdate, onError: _handleLocationError);
  }

  void _handleLocationUpdate(LocationSnapshot location) {
    if (!mounted) return;
    state = state.copyWith(
      lastLocation: location,
      route: _appendRoutePoint(state.route, location),
      gpsEnabled: true,
      permissionDenied: false,
      trackingStatus: _activityFor(location),
      clearError: true,
    );

    if (state.trackingEnabled) {
      unawaited(_publishLiveLocation(location));
    }
  }

  void _handleLocationError(Object error) {
    if (!mounted) return;
    final denied =
        error is LocationServiceException &&
        error.message.toLowerCase().contains('permission');
    state = state.copyWith(
      gpsEnabled: false,
      permissionDenied: denied,
      error: '$error',
    );
  }

  List<LocationSnapshot> _appendRoutePoint(
    List<LocationSnapshot> source,
    LocationSnapshot location,
  ) {
    final next = List<LocationSnapshot>.from(source);
    if (next.isNotEmpty) {
      final last = next.last;
      final distance = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        location.latitude,
        location.longitude,
      );
      if (distance < 2) {
        next[next.length - 1] = location;
        return next;
      }
    }
    next.add(location);
    if (next.length > 180) {
      next.removeRange(0, next.length - 180);
    }
    return List<LocationSnapshot>.unmodifiable(next);
  }

  Future<void> toggleTracking() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      clearSyncSummary: true,
    );
    try {
      final service = _ref.read(backgroundTrackingServiceProvider);
      if (service.isEnabled) {
        await service.stop();
        await _ref
            .read(trackingTransportServiceProvider)
            .pushStatusChange('OFFLINE');
      } else {
        await service.start();
        await _ref
            .read(trackingTransportServiceProvider)
            .pushStatusChange(state.trackingStatus);
      }

      state = state.copyWith(
        loading: false,
        trackingEnabled: service.isEnabled,
        lastSyncSummary: service.isEnabled
            ? 'Live tracking enabled for foreground and background updates.'
            : 'Live tracking paused.',
      );

      if (service.isEnabled && state.lastLocation != null) {
        await _publishLiveLocation(state.lastLocation!, force: true);
      }
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> captureLocationPing() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final location = await _ref
          .read(locationServiceProvider)
          .currentLocation();
      final payload = await _buildPayload(location, activity: 'MANUAL_PING');
      final result = await _ref
          .read(trackingTransportServiceProvider)
          .publishLocation(payload);
      final count = await _ref.read(offlineQueueProvider).pendingCount();
      state = state.copyWith(
        loading: false,
        lastLocation: location,
        route: _appendRoutePoint(state.route, location),
        pendingSyncItems: count,
        lastSyncSummary: result.delivered
            ? 'Manual ping delivered.'
            : 'Manual ping queued for retry.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> _publishLiveLocation(
    LocationSnapshot location, {
    bool force = false,
  }) async {
    if (!force && !_shouldPublish(location)) {
      return;
    }

    _lastPublishedAt = DateTime.now();
    _lastPublishedLocation = location;
    final activity = _activityFor(location);
    final payload = await _buildPayload(location, activity: activity);
    final result = await _ref
        .read(trackingTransportServiceProvider)
        .publishLocation(payload);
    final count = await _ref.read(offlineQueueProvider).pendingCount();
    if (!mounted) return;
    state = state.copyWith(
      pendingSyncItems: count,
      trackingStatus: activity,
      lastSyncSummary: result.delivered
          ? (result.viaSocket
                ? 'Live update sent over realtime socket.'
                : 'Live update delivered by REST fallback.')
          : 'Live update queued for retry.',
    );
  }

  bool _shouldPublish(LocationSnapshot location) {
    final publishedAt = _lastPublishedAt;
    final publishedLocation = _lastPublishedLocation;
    if (publishedAt == null || publishedLocation == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(publishedAt);
    final moving = location.speed >= 1.2;
    final threshold = moving
        ? const Duration(seconds: 8)
        : const Duration(seconds: 45);
    final distance = Geolocator.distanceBetween(
      publishedLocation.latitude,
      publishedLocation.longitude,
      location.latitude,
      location.longitude,
    );
    return elapsed >= threshold || distance >= (moving ? 15 : 8);
  }

  String _activityFor(LocationSnapshot location) {
    return location.speed >= 1.2 ? 'MOVING' : 'IDLE';
  }

  Future<TrackingPayload> _buildPayload(
    LocationSnapshot location, {
    required String activity,
  }) async {
    final device = await _ref.read(deviceStatusServiceProvider).snapshot();
    return TrackingPayload(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      speed: math.max(0, location.speed),
      heading: location.heading,
      batteryPercent: device.batteryPercent,
      internetStatus: device.internetStatus,
      recordedAt: location.timestamp,
      activity: activity,
      isMocked: location.isMocked,
    );
  }

  Future<void> syncNow() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _ref.read(trackingTransportServiceProvider).flushQueue();
      final count = await _ref.read(offlineQueueProvider).pendingCount();
      state = state.copyWith(
        loading: false,
        pendingSyncItems: count,
        lastSyncSummary: count == 0
            ? 'All pending tracking updates flushed.'
            : '$count tracking update(s) still pending.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  void toggleFollowEmployee() {
    state = state.copyWith(followEmployee: !state.followEmployee);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _serverSubscription?.cancel();
    _statusSubscription?.cancel();
    _deviceTimer?.cancel();
    super.dispose();
  }
}
