import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/live_employee.dart';

enum DashboardConnectionStatus { connecting, connected, disconnected }

class PlaybackPoint {
  const PlaybackPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.distanceMeters,
    required this.recordedAt,
    required this.activity,
    this.address = 'Field location',
    this.visitId,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double distanceMeters;
  final DateTime recordedAt;
  final String activity;
  final String address;
  final String? visitId;

  LatLng get latLng => LatLng(latitude, longitude);
}

class VisitMapPin {
  const VisitMapPin({
    required this.id,
    required this.employeeId,
    required this.clientName,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.submittedAt,
    required this.status,
    required this.photoCount,
    required this.notesCount,
    this.photoUrl,
    this.employeeName = 'Employee',
    this.locationLabel,
  });

  final String id;
  final String employeeId;
  final String clientName;
  final String notes;
  final double latitude;
  final double longitude;
  final DateTime submittedAt;
  final String status;
  final int photoCount;
  final int notesCount;
  final String? photoUrl;
  final String employeeName;
  final String? locationLabel;

  LatLng get latLng => LatLng(latitude, longitude);
}

class LiveTrackingState {
  const LiveTrackingState({
    this.loading = false,
    this.employees = const [],
    this.visitPins = const [],
    this.routeVisitPins = const [],
    this.routeTrails = const {},
    this.search = '',
    this.statusFilter = 'all',
    this.selectedDate,
    this.selectedEmployeeId,
    this.connectionStatus = DashboardConnectionStatus.connecting,
    this.playback = const [],
    this.playbackIndex = 0,
    this.playbackLoading = false,
    this.playbackPlaying = false,
    this.playbackSpeed = 1,
    this.error,
  });

  final bool loading;
  final List<LiveEmployee> employees;
  final List<VisitMapPin> visitPins;
  final List<VisitMapPin> routeVisitPins;
  final Map<String, List<PlaybackPoint>> routeTrails;
  final String search;
  final String statusFilter;
  final DateTime? selectedDate;
  final String? selectedEmployeeId;
  final DashboardConnectionStatus connectionStatus;
  final List<PlaybackPoint> playback;
  final int playbackIndex;
  final bool playbackLoading;
  final bool playbackPlaying;
  final int playbackSpeed;
  final String? error;

  List<LiveEmployee> get filteredEmployees {
    final query = search.trim().toLowerCase();
    final searched = query.isEmpty
        ? employees
        : employees
              .where((employee) {
                return employee.name.toLowerCase().contains(query) ||
                    employee.employeeCode.toLowerCase().contains(query) ||
                    employee.department.toLowerCase().contains(query);
              })
              .toList(growable: false);

    if (statusFilter == 'all') return searched;
    return searched
        .where((employee) {
          final status = employee.trackingStatus.toLowerCase();
          return switch (statusFilter) {
            'online' => employee.isOnline,
            'offline' => !employee.isOnline,
            'moving' => status.contains('moving') || status.contains('travel'),
            'idle' =>
              status.contains('idle') ||
                  status.contains('stationary') ||
                  status.contains('no_location'),
            'violations' => employee.accuracy > 100,
            _ => true,
          };
        })
        .toList(growable: false);
  }

  LiveEmployee? get selectedEmployee {
    if (selectedEmployeeId == null) {
      return filteredEmployees.isEmpty ? null : filteredEmployees.first;
    }
    for (final employee in employees) {
      if (employee.id == selectedEmployeeId) return employee;
    }
    return filteredEmployees.isEmpty ? null : filteredEmployees.first;
  }

  PlaybackPoint? get playbackCursor {
    if (playback.isEmpty || playbackIndex >= playback.length) return null;
    return playback[playbackIndex];
  }

  DateTime get routeDate => selectedDate ?? DateTime.now();

  bool get hasDailyRoute => playback.isNotEmpty || routeVisitPins.isNotEmpty;

  LiveTrackingState copyWith({
    bool? loading,
    List<LiveEmployee>? employees,
    List<VisitMapPin>? visitPins,
    List<VisitMapPin>? routeVisitPins,
    Map<String, List<PlaybackPoint>>? routeTrails,
    String? search,
    String? statusFilter,
    DateTime? selectedDate,
    String? selectedEmployeeId,
    DashboardConnectionStatus? connectionStatus,
    List<PlaybackPoint>? playback,
    int? playbackIndex,
    bool? playbackLoading,
    bool? playbackPlaying,
    int? playbackSpeed,
    String? error,
    bool clearDate = false,
    bool clearError = false,
  }) {
    return LiveTrackingState(
      loading: loading ?? this.loading,
      employees: employees ?? this.employees,
      visitPins: visitPins ?? this.visitPins,
      routeVisitPins: routeVisitPins ?? this.routeVisitPins,
      routeTrails: routeTrails ?? this.routeTrails,
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      selectedDate: clearDate ? null : selectedDate ?? this.selectedDate,
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      playback: playback ?? this.playback,
      playbackIndex: playbackIndex ?? this.playbackIndex,
      playbackLoading: playbackLoading ?? this.playbackLoading,
      playbackPlaying: playbackPlaying ?? this.playbackPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LiveTrackingViewModel extends StateNotifier<LiveTrackingState> {
  LiveTrackingViewModel({required SupabaseClient supabase})
    : _supabase = supabase,
      super(const LiveTrackingState()) {
    unawaited(_initialize());
  }

  final SupabaseClient _supabase;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  StreamSubscription<List<Map<String, dynamic>>>? _visitSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _historySubscription;
  Timer? _playbackTimer;
  Timer? _heartbeatTimer;
  Map<String, Map<String, dynamic>> _profilesById = const {};

  Future<void> _initialize() async {
    await refresh();
    await _subscribeRealtime();
    _startHeartbeatTimer();
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    // Refresh every 15 seconds to update online/offline status based on time
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshOnlineStatus();
    });
  }

  void _refreshOnlineStatus() {
    if (state.employees.isEmpty) return;

    final nowUtc = DateTime.now().toUtc();
    var hasChanges = false;

    final updatedEmployees = state.employees
        .map((employee) {
          // Skip employees with no location data
          if (employee.lastSyncAt.millisecondsSinceEpoch == 0) {
            return employee;
          }

          final recordedAtUtc = employee.lastSyncAt.isUtc
              ? employee.lastSyncAt
              : employee.lastSyncAt.toUtc();
          final secondsDiff = nowUtc.difference(recordedAtUtc).inSeconds;
          final isOnline = secondsDiff <= 60;

          if (employee.isOnline != isOnline) {
            debugPrint(
              '[TrackingDebug] ${employee.name} status changed: ${employee.isOnline} -> $isOnline (last update ${secondsDiff}s ago)',
            );
            hasChanges = true;
            return employee.copyWith(isOnline: isOnline);
          }
          return employee;
        })
        .toList(growable: false);

    if (hasChanges) {
      state = state.copyWith(employees: updatedEmployees);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final profileRows =
          await _supabase
                  .from('profiles')
                  .select(
                    'id, auth_user_id, full_name, employee_id, department_id, team_id, phone, role, status, organization_id, meta',
                  )
                  .ilike('role', 'employee')
              as List<dynamic>? ??
          const [];

      final profiles = profileRows
          .map((row) {
            return Map<String, dynamic>.from(row as Map);
          })
          .toList(growable: false);
      _profilesById = {
        for (final row in profiles)
          for (final key in [
            row['id']?.toString(),
            row['auth_user_id']?.toString(),
            row['employee_id']?.toString(),
          ])
            if (key != null && key.isNotEmpty) key: row,
      };
      debugPrint('[TrackingDebug] profiles loaded=${profiles.length}');

      final locationRows =
          await _supabase
                  .from('live_locations')
                  .select()
                  .order('recorded_at', ascending: false)
                  .limit(1000)
              as List<dynamic>? ??
          const [];
      debugPrint(
        '[TrackingDebug] live_locations loaded=${locationRows.length}',
      );

      final historyRows =
          await _supabase
                  .from('location_history')
                  .select()
                  .order('recorded_at', ascending: false)
                  .limit(1000)
              as List<dynamic>? ??
          const [];
      debugPrint(
        '[TrackingDebug] location_history loaded=${historyRows.length}',
      );

      final latestByEmployee = <String, Map<String, dynamic>>{};
      for (final row in locationRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final employeeId = map['employee_id']?.toString() ?? '';
        if (employeeId.isNotEmpty) {
          latestByEmployee.putIfAbsent(employeeId, () => map);
        }
      }

      final employees =
          latestByEmployee.entries
              .map((entry) {
                return _fromJson(
                  _mergeLocationWithProfile(entry.value, entry.key),
                );
              })
              .followedBy(
                profiles
                    .where((profile) {
                      final id = profile['id']?.toString() ?? '';
                      return id.isNotEmpty && !latestByEmployee.containsKey(id);
                    })
                    .map((profile) {
                      final id = profile['id']?.toString() ?? '';
                      return _fromJson(
                        _mergeLocationWithProfile(
                          const <String, dynamic>{},
                          id,
                        ),
                      );
                    }),
              )
              .where((employee) => employee.id.isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) => b.lastSyncAt.compareTo(a.lastSyncAt));

      // Debug: Log employee status
      for (final emp in employees) {
        debugPrint(
          '[TrackingDebug] ${emp.name}: isOnline=${emp.isOnline}, lastSync=${emp.lastSyncAt}, status=${emp.trackingStatus}',
        );
      }
      debugPrint(
        '[TrackingDebug] employee markers prepared=${employees.length}, online=${employees.where((e) => e.isOnline).length}',
      );

      final selectedEmployeeId = _resolveSelectedEmployee(
        state.selectedEmployeeId,
        employees,
      );
      final nextTrails = _historyTrails(historyRows);
      for (final employee in employees) {
        if (employee.latitude == 0 && employee.longitude == 0) continue;
        nextTrails[employee.id] = _appendTrail(
          nextTrails[employee.id] ?? const [],
          PlaybackPoint(
            latitude: employee.latitude,
            longitude: employee.longitude,
            accuracy: employee.accuracy,
            speed: employee.speed,
            distanceMeters: employee.distanceTodayMeters,
            recordedAt: employee.lastSyncAt,
            activity: employee.trackingStatus,
          ),
        );
      }
      state = state.copyWith(
        loading: false,
        employees: employees,
        visitPins: const [],
        routeVisitPins: const [],
        routeTrails: nextTrails,
        selectedEmployeeId: selectedEmployeeId,
        connectionStatus: DashboardConnectionStatus.connected,
        clearError: true,
      );
      debugPrint(
        '[TrackingDebug] marker rendered employees=${employees.where((e) => e.latitude != 0 || e.longitude != 0).length} routes=${nextTrails.length}',
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        connectionStatus: DashboardConnectionStatus.disconnected,
        error: '$error',
      );
    }
  }

  Future<void> _subscribeRealtime() async {
    await _subscription?.cancel();
    await _visitSubscription?.cancel();
    await _historySubscription?.cancel();
    state = state.copyWith(
      connectionStatus: DashboardConnectionStatus.connecting,
    );

    _subscription = _supabase
        .from('live_locations')
        .stream(primaryKey: ['id'])
        .listen(
          (payload) {
            debugPrint(
              '[TrackingDebug] realtime live_locations event received rows=${payload.length}',
            );
            for (final raw in payload) {
              final data = Map<String, dynamic>.from(raw);
              final employeeId = data['employee_id']?.toString() ?? '';
              final employee = _fromJson(
                _mergeLocationWithProfile(data, employeeId),
              );
              if (employee.id.isEmpty) continue;

              final nextEmployees = List<LiveEmployee>.from(state.employees);
              final index = nextEmployees.indexWhere(
                (item) => item.id == employee.id,
              );
              if (index >= 0) {
                nextEmployees[index] = employee;
                debugPrint('[TrackingDebug] employee updated ${employee.id}');
              } else {
                nextEmployees.add(employee);
                debugPrint('[TrackingDebug] employee added ${employee.id}');
              }
              nextEmployees.sort(
                (a, b) => b.lastSyncAt.compareTo(a.lastSyncAt),
              );

              final point = PlaybackPoint(
                latitude: employee.latitude,
                longitude: employee.longitude,
                accuracy: employee.accuracy,
                speed: employee.speed,
                distanceMeters: employee.distanceTodayMeters,
                recordedAt: employee.lastSyncAt,
                activity: employee.trackingStatus,
              );

              final nextTrails =
                  Map<String, List<PlaybackPoint>>.from(state.routeTrails)
                    ..[employee.id] = _appendTrail(
                      state.routeTrails[employee.id] ?? const [],
                      point,
                    );
              final shouldExtendDailyRoute =
                  state.hasDailyRoute &&
                  state.selectedEmployeeId == employee.id &&
                  _sameLocalDay(point.recordedAt, state.routeDate);
              final nextPlayback = shouldExtendDailyRoute
                  ? _mergeRoutePoints([...state.playback, point])
                  : state.playback;

              if (!mounted) return;
              state = state.copyWith(
                employees: nextEmployees,
                routeTrails: nextTrails,
                playback: nextPlayback,
                playbackIndex: shouldExtendDailyRoute && nextPlayback.isNotEmpty
                    ? nextPlayback.length - 1
                    : state.playbackIndex,
                selectedEmployeeId: state.selectedEmployeeId ?? employee.id,
                connectionStatus: DashboardConnectionStatus.connected,
                clearError: true,
              );
              debugPrint(
                '[TrackingDebug] marker updated ${employee.name} ${employee.latitude},${employee.longitude}',
              );
            }
          },
          onDone: () {
            if (!mounted) return;
            state = state.copyWith(
              connectionStatus: DashboardConnectionStatus.disconnected,
            );
          },
          onError: (error) {
            if (!mounted) return;
            state = state.copyWith(
              connectionStatus: DashboardConnectionStatus.disconnected,
              error: '$error',
            );
          },
        );

    _visitSubscription = _supabase
        .from('visits')
        .stream(primaryKey: ['id'])
        .listen((payload) {
          debugPrint(
            '[TrackingDebug] realtime visits event received rows=${payload.length}',
          );
          unawaited(refresh());
        });

    _historySubscription = _supabase
        .from('location_history')
        .stream(primaryKey: ['id'])
        .listen((payload) {
          debugPrint(
            '[TrackingDebug] realtime location_history event received rows=${payload.length}',
          );
          _mergeHistoryPayload(payload);
        });
  }

  Map<String, List<PlaybackPoint>> _historyTrails(List<dynamic> rows) {
    final grouped = <String, List<PlaybackPoint>>{};
    for (final row in rows.reversed) {
      final json = Map<String, dynamic>.from(row as Map);
      final employeeId = json['employee_id']?.toString() ?? '';
      if (employeeId.isEmpty) continue;
      final point = _historyPointFromJson(json);
      if (point.latitude == 0 && point.longitude == 0) continue;
      grouped.putIfAbsent(employeeId, () => <PlaybackPoint>[]).add(point);
    }
    debugPrint('[TrackingDebug] route rendered groups=${grouped.length}');
    return {
      for (final entry in grouped.entries)
        entry.key: List<PlaybackPoint>.unmodifiable(entry.value),
    };
  }

  PlaybackPoint _historyPointFromJson(Map<String, dynamic> json) {
    return PlaybackPoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      recordedAt:
          DateTime.tryParse(json['recorded_at'] as String? ?? '') ??
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      activity:
          json['activity'] as String? ??
          json['tracking_status'] as String? ??
          'ACTIVE',
      address: json['readable_location'] as String? ?? 'GPS point',
    );
  }

  void _mergeHistoryPayload(List<Map<String, dynamic>> payload) {
    if (payload.isEmpty) return;
    final byEmployee = <String, List<PlaybackPoint>>{};
    for (final raw in payload) {
      final json = Map<String, dynamic>.from(raw);
      final employeeId = json['employee_id']?.toString() ?? '';
      if (employeeId.isEmpty) continue;
      final point = _historyPointFromJson(json);
      if (point.latitude == 0 && point.longitude == 0) continue;
      byEmployee.putIfAbsent(employeeId, () => <PlaybackPoint>[]).add(point);
    }
    if (byEmployee.isEmpty || !mounted) return;

    final nextTrails = Map<String, List<PlaybackPoint>>.from(state.routeTrails);
    var nextPlayback = state.playback;
    var changedPlayback = false;
    for (final entry in byEmployee.entries) {
      final sorted = [...entry.value]
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      final mergedTrail = _mergeRoutePoints([
        ...(nextTrails[entry.key] ?? const <PlaybackPoint>[]),
        ...sorted,
      ]);
      nextTrails[entry.key] = _trimTrail(mergedTrail);
      if (state.hasDailyRoute && entry.key == state.selectedEmployeeId) {
        final dayPoints = sorted
            .where((point) => _sameLocalDay(point.recordedAt, state.routeDate))
            .toList(growable: false);
        if (dayPoints.isNotEmpty) {
          nextPlayback = _mergeRoutePoints([...nextPlayback, ...dayPoints]);
          changedPlayback = true;
        }
      }
    }

    state = state.copyWith(
      routeTrails: nextTrails,
      playback: nextPlayback,
      playbackIndex: changedPlayback && nextPlayback.isNotEmpty
          ? nextPlayback.length - 1
          : state.playbackIndex,
    );
  }

  List<PlaybackPoint> _appendTrail(
    List<PlaybackPoint> source,
    PlaybackPoint point,
  ) {
    final next = List<PlaybackPoint>.from(source);
    if (next.isNotEmpty) {
      final last = next.last;
      final closeBy =
          const Distance().as(LengthUnit.Meter, last.latLng, point.latLng) < 2;
      if (closeBy) {
        next[next.length - 1] = point;
      } else {
        next.add(point);
      }
    } else {
      next.add(point);
    }
    if (next.length > 80) {
      next.removeRange(0, next.length - 80);
    }
    return List<PlaybackPoint>.unmodifiable(next);
  }

  List<PlaybackPoint> _trimTrail(List<PlaybackPoint> points) {
    if (points.length <= 80) return List<PlaybackPoint>.unmodifiable(points);
    return List<PlaybackPoint>.unmodifiable(points.skip(points.length - 80));
  }

  void updateSearch(String value) {
    state = state.copyWith(search: value);
  }

  void updateStatusFilter(String value) {
    state = state.copyWith(statusFilter: value);
  }

  void updateSelectedDate(DateTime? value) {
    state = value == null
        ? state.copyWith(clearDate: true)
        : state.copyWith(selectedDate: value);
    final selected = state.selectedEmployee;
    if (selected != null && state.hasDailyRoute) {
      unawaited(loadPlayback(selected.id));
    }
  }

  void selectEmployee(String employeeId) {
    state = state.copyWith(
      selectedEmployeeId: employeeId,
      playback: const [],
      playbackIndex: 0,
      playbackPlaying: false,
      routeVisitPins: const [],
    );
  }

  Future<void> loadPlayback(String employeeId) async {
    _playbackTimer?.cancel();
    state = state.copyWith(
      playbackLoading: true,
      playbackPlaying: false,
      routeVisitPins: const [],
      clearError: true,
    );
    try {
      final routeDate = state.routeDate;
      final start = DateTime(routeDate.year, routeDate.month, routeDate.day);
      final end = start.add(const Duration(days: 1));
      var query = _supabase
          .from('location_history')
          .select()
          .eq('employee_id', employeeId);
      query = query
          .gte('recorded_at', start.toIso8601String())
          .lt('recorded_at', end.toIso8601String());
      final rows =
          await query.order('recorded_at', ascending: true) as List<dynamic>? ??
          const [];
      final playback = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(_historyPointFromJson)
          .where((point) => point.latitude != 0 || point.longitude != 0)
          .toList(growable: false);
      final dailyRoute = _mergeRoutePoints(playback);

      state = state.copyWith(
        playbackLoading: false,
        playback: dailyRoute,
        routeVisitPins: const [],
        routeTrails: {...state.routeTrails, employeeId: _trimTrail(dailyRoute)},
        playbackIndex: dailyRoute.isEmpty ? 0 : dailyRoute.length - 1,
      );
    } catch (error) {
      state = state.copyWith(playbackLoading: false, error: '$error');
    }
  }

  void togglePlayback() {
    if (state.playback.isEmpty) return;
    if (state.playbackPlaying) {
      _playbackTimer?.cancel();
      state = state.copyWith(playbackPlaying: false);
      return;
    }

    state = state.copyWith(playbackPlaying: true);
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted) return;
      final increment = math.max(1, state.playbackSpeed);
      final nextIndex = state.playbackIndex + increment;
      if (nextIndex >= state.playback.length) {
        _playbackTimer?.cancel();
        state = state.copyWith(
          playbackIndex: state.playback.length - 1,
          playbackPlaying: false,
        );
      } else {
        state = state.copyWith(playbackIndex: nextIndex);
      }
    });
  }

  void seekPlayback(double value) {
    final index =
        value.round().clamp(0, math.max(0, state.playback.length - 1)) as int;
    state = state.copyWith(playbackIndex: index);
  }

  void setPlaybackSpeed(int speed) {
    state = state.copyWith(playbackSpeed: speed);
  }

  List<PlaybackPoint> _mergeRoutePoints(Iterable<PlaybackPoint> points) {
    final sorted =
        points
            .where((point) => point.latitude != 0 || point.longitude != 0)
            .toList(growable: false)
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final merged = <PlaybackPoint>[];
    for (final point in sorted) {
      if (merged.isEmpty) {
        merged.add(point);
        continue;
      }
      final last = merged.last;
      final sameVisit =
          point.visitId != null &&
          point.visitId == last.visitId &&
          last.visitId != null;
      final sameRecordedPoint =
          point.recordedAt.isAtSameMomentAs(last.recordedAt) &&
          const Distance().as(LengthUnit.Meter, last.latLng, point.latLng) < 2;
      if (sameVisit || sameRecordedPoint) {
        merged[merged.length - 1] = point;
      } else {
        merged.add(point);
      }
    }
    return List<PlaybackPoint>.unmodifiable(merged);
  }

  bool _sameLocalDay(DateTime left, DateTime right) {
    final a = left.toLocal();
    final b = right.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<PlaybackPoint> stopMarkers() {
    if (state.playback.length < 3) return const [];
    final stops = <PlaybackPoint>[];
    for (var index = 1; index < state.playback.length; index++) {
      final previous = state.playback[index - 1];
      final current = state.playback[index];
      final pauseMinutes = current.recordedAt
          .difference(previous.recordedAt)
          .inMinutes;
      final distanceMeters = const Distance().as(
        LengthUnit.Meter,
        previous.latLng,
        current.latLng,
      );
      if (pauseMinutes >= 10 || (pauseMinutes >= 5 && distanceMeters < 20)) {
        stops.add(current);
      }
    }
    return stops;
  }

  Color statusColor(LiveEmployee employee) {
    final status = employee.trackingStatus.toLowerCase();
    if (!employee.isOnline || status.contains('offline')) {
      return const Color(0xFFFF6B6B);
    }
    if (status.contains('moving') || status.contains('travel')) {
      return const Color(0xFF54F1A6);
    }
    if (status.contains('idle') || status.contains('break')) {
      return const Color(0xFF5CE1E6);
    }
    return const Color(0xFF54F1A6);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _visitSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  String? _resolveSelectedEmployee(
    String? current,
    List<LiveEmployee> employees,
  ) {
    if (current != null &&
        employees.any((employee) => employee.id == current)) {
      return current;
    }
    return employees.isEmpty ? null : employees.first.id;
  }

  Map<String, dynamic> _mergeLocationWithProfile(
    Map<String, dynamic> location,
    String employeeId,
  ) {
    final profile = _profilesById[employeeId] ?? const <String, dynamic>{};
    final hasLocation = location.isNotEmpty;
    return {
      ...location,
      'id': employeeId,
      if (!hasLocation) 'activity': 'NO_LOCATION',
      if (!hasLocation) 'recorded_at': null,
      'profile_employee_id': profile['employee_id'],
      'full_name': profile['full_name'],
      'department_id': profile['department_id'],
      'team_id': profile['team_id'],
      'phone': profile['phone'],
      'role': profile['role'],
      'profile_status': profile['status'],
      'profile_meta': profile['meta'],
    };
  }

  LiveEmployee _fromJson(Map<String, dynamic> json) {
    final meta = Map<String, dynamic>.from(
      (json['profile_meta'] ?? json['meta']) as Map? ?? const {},
    );
    final recordedAt =
        DateTime.tryParse(json['recorded_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final activity =
        json['activity'] as String? ??
        json['currentActivity'] as String? ??
        json['status'] as String? ??
        'OFFLINE';
    final accuracy = (json['accuracy'] as num?)?.toDouble() ?? 0;

    return LiveEmployee(
      id: json['id'] as String? ?? '',
      employeeCode:
          _cleanEmployeeCode(json['profile_employee_id']) ??
          _cleanEmployeeCode(json['employee_code']) ??
          _cleanEmployeeCode(meta['employeeCode']) ??
          'Employee ID pending',
      name:
          json['full_name'] as String? ??
          json['fullName'] as String? ??
          meta['fullName'] as String? ??
          'Employee',
      department:
          json['department'] as String? ??
          json['department_id'] as String? ??
          meta['department'] as String? ??
          'Operations',
      designation:
          json['designation'] as String? ??
          meta['designation'] as String? ??
          'Field Executive',
      teamName:
          json['teamName'] as String? ??
          json['team_id'] as String? ??
          'Field Team',
      branchLabel: json['branchLabel'] as String? ?? 'Assigned territory',
      status: json['profile_status'] as String? ?? activity,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0,
      accuracy: accuracy,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      distanceTodayMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      battery:
          (json['battery_percent'] as num?)?.toInt() ??
          (json['batteryPercent'] as num?)?.toInt() ??
          0,
      internetStatus:
          json['internet_status'] as String? ??
          json['internetStatus'] as String? ??
          'Unknown',
      gpsStatus: accuracy <= 0 ? 'Unknown' : (accuracy <= 100 ? 'On' : 'Weak'),
      lastSyncAt: recordedAt,
      lastActiveAt: recordedAt,
      trackingStatus: activity,
      isOnline: _isOnline(recordedAt),
    );
  }

  bool _isOnline(DateTime recordedAt) {
    if (recordedAt.millisecondsSinceEpoch == 0) {
      debugPrint(
        '[TrackingDebug] _isOnline: millisecondsSinceEpoch == 0, returning false',
      );
      return false;
    }
    // Compare in UTC to avoid timezone issues
    final nowUtc = DateTime.now().toUtc();
    final recordedAtUtc = recordedAt.isUtc ? recordedAt : recordedAt.toUtc();
    final diffSeconds = nowUtc.difference(recordedAtUtc).inSeconds;
    debugPrint(
      '[TrackingDebug] _isOnline: now=$nowUtc, recorded=$recordedAtUtc, diff=${diffSeconds}s, online=${diffSeconds <= 60}',
    );
    return diffSeconds <= 60;
  }

  String? _cleanEmployeeCode(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidPattern.hasMatch(text)) return null;
    return text;
  }
}
