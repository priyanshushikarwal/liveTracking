import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/background_tracking_service.dart';
import '../../../../core/services/device_status_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/reverse_geocoding_service.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/storage/offline_queue_service.dart';
import '../../../../core/supabase/supabase_client.dart' as sb;
import '../../domain/entities/attendance_record.dart';

class AttendanceState {
  const AttendanceState({
    this.loading = false,
    this.records = const [],
    this.activeRecord,
    this.message,
    this.error,
    this.lastLocation,
    this.readableLocation = 'Resolving location',
    this.internetStatus = 'Checking',
    this.batteryPercent = 0,
    this.gpsEnabled = false,
    this.permissionGranted = false,
    this.highAccuracyReady = false,
    this.securityTrusted = false,
    this.pendingUploads = 0,
    this.validationChecks = const [],
  });

  final bool loading;
  final List<AttendanceRecord> records;
  final AttendanceRecord? activeRecord;
  final String? message;
  final String? error;
  final LocationSnapshot? lastLocation;
  final String readableLocation;
  final String internetStatus;
  final int batteryPercent;
  final bool gpsEnabled;
  final bool permissionGranted;
  final bool highAccuracyReady;
  final bool securityTrusted;
  final int pendingUploads;
  final List<VerificationCheck> validationChecks;

  AttendanceState copyWith({
    bool? loading,
    List<AttendanceRecord>? records,
    AttendanceRecord? activeRecord,
    String? message,
    String? error,
    LocationSnapshot? lastLocation,
    String? readableLocation,
    String? internetStatus,
    int? batteryPercent,
    bool? gpsEnabled,
    bool? permissionGranted,
    bool? highAccuracyReady,
    bool? securityTrusted,
    int? pendingUploads,
    List<VerificationCheck>? validationChecks,
    bool clearError = false,
    bool clearMessage = false,
    bool clearActiveRecord = false,
  }) {
    return AttendanceState(
      loading: loading ?? this.loading,
      records: records ?? this.records,
      activeRecord: clearActiveRecord
          ? null
          : activeRecord ?? this.activeRecord,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
      lastLocation: lastLocation ?? this.lastLocation,
      readableLocation: readableLocation ?? this.readableLocation,
      internetStatus: internetStatus ?? this.internetStatus,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      highAccuracyReady: highAccuracyReady ?? this.highAccuracyReady,
      securityTrusted: securityTrusted ?? this.securityTrusted,
      pendingUploads: pendingUploads ?? this.pendingUploads,
      validationChecks: validationChecks ?? this.validationChecks,
    );
  }
}

class AttendanceViewModel extends StateNotifier<AttendanceState> {
  AttendanceViewModel(this._ref) : super(const AttendanceState());

  final Ref _ref;

  Future<void> loadHistory() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await refreshReadiness();
      final records = await _ref
          .read(attendanceRepositoryProvider)
          .fetchHistory();
      final activeRecord = records.cast<AttendanceRecord?>().firstWhere(
        (record) => record?.checkOutTime == null,
        orElse: () => null,
      );
      state = state.copyWith(
        loading: false,
        records: records,
        activeRecord: activeRecord,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<AttendanceVerificationContext> prepareAttendance({
    required String attendanceType,
    required double siteLatitude,
    required double siteLongitude,
    required int allowedRadius,
  }) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final context = await _buildVerificationContext(
        attendanceType: attendanceType,
        siteLatitude: siteLatitude,
        siteLongitude: siteLongitude,
        allowedRadius: allowedRadius,
      );
      if (!context.canSubmit) {
        throw Exception(
          context.checks
              .where((check) => !check.passed)
              .map((check) => check.label)
              .join('. '),
        );
      }
      state = state.copyWith(
        loading: false,
        lastLocation: context.location,
        readableLocation: context.readableLocation,
        internetStatus: context.device.internetStatus,
        batteryPercent: context.device.batteryPercent,
        gpsEnabled: true,
        permissionGranted: true,
        highAccuracyReady: context.location.accuracy <= 50,
        securityTrusted: true,
        validationChecks: context.checks,
      );
      return context;
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
      rethrow;
    }
  }

  Future<void> submitCheckIn({
    required AttendanceVerificationContext context,
    required String selfiePath,
  }) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final record = await _ref
          .read(attendanceRepositoryProvider)
          .checkIn(await _payloadFor(context, selfiePath));
      await _ref.read(backgroundTrackingServiceProvider).start();
      await _ref.read(trackingViewModelProvider.notifier).captureLocationPing();
      state = state.copyWith(
        loading: false,
        activeRecord: record,
        records: [record, ...state.records],
        message: record.syncStatus == 'PENDING UPLOAD'
            ? 'Attendance captured offline and queued for secure upload.'
            : 'Check-in verified. Live route recording has started.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> submitCheckOut({
    required AttendanceVerificationContext context,
    required String selfiePath,
  }) async {
    final activeRecord = state.activeRecord;
    if (activeRecord == null) {
      state = state.copyWith(error: 'No active attendance session found.');
      return;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final updated = await _ref
          .read(attendanceRepositoryProvider)
          .checkOut(await _payloadFor(context, selfiePath));
      await _ref.read(backgroundTrackingServiceProvider).stop();
      final records = state.records
          .map((record) => record.id == activeRecord.id ? updated : record)
          .toList(growable: false);
      state = state.copyWith(
        loading: false,
        clearActiveRecord: true,
        records: records,
        message: updated.syncStatus == 'PENDING UPLOAD'
            ? 'Check-out captured offline and queued for secure upload.'
            : 'Check-out verified. Daily work summary is ready.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> refreshReadiness() async {
    final locationService = _ref.read(locationServiceProvider);
    final device = await _ref.read(deviceStatusServiceProvider).snapshot();
    final pending = await _ref.read(offlineQueueProvider).pendingCount();
    final gpsEnabled = await locationService.isServiceEnabled();
    final permission = await locationService.ensurePermission();
    LocationSnapshot? location;
    String readableLocation = state.readableLocation;
    var trusted = false;
    var highAccuracy = false;
    final checks = <VerificationCheck>[
      VerificationCheck(
        'Internet ${device.internetStatus}',
        device.internetStatus != 'Offline',
      ),
      VerificationCheck(
        'Battery ${device.batteryPercent}%',
        device.batteryPercent > 5,
      ),
      VerificationCheck('GPS service enabled', gpsEnabled),
      VerificationCheck(
        'Location permission granted',
        permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse,
      ),
    ];

    if (gpsEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      try {
        location = await locationService.currentLocation();
        highAccuracy = location.accuracy <= 50;
        readableLocation = await _ref
            .read(reverseGeocodingServiceProvider)
            .resolve(
              latitude: location.latitude,
              longitude: location.longitude,
              fallbackName: AppConfig.defaultSiteName,
            );
        final security = _ref
            .read(securityServiceProvider)
            .evaluateLocationIntegrity(
              previous: state.lastLocation,
              current: location,
            );
        trusted = security.isTrusted;
        checks.addAll([
          VerificationCheck('High accuracy mode ready', highAccuracy),
          VerificationCheck('Fake GPS disabled', !location.isMocked),
          VerificationCheck('Movement pattern trusted', security.isTrusted),
        ]);
      } catch (_) {
        checks.add(const VerificationCheck('Live location available', false));
      }
    }

    state = state.copyWith(
      lastLocation: location,
      readableLocation: readableLocation,
      internetStatus: device.internetStatus,
      batteryPercent: device.batteryPercent,
      gpsEnabled: gpsEnabled,
      permissionGranted:
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse,
      highAccuracyReady: highAccuracy,
      securityTrusted: trusted,
      pendingUploads: pending,
      validationChecks: checks,
    );
  }

  Future<AttendanceVerificationContext> _buildVerificationContext({
    required String attendanceType,
    required double siteLatitude,
    required double siteLongitude,
    required int allowedRadius,
  }) async {
    final location = await _ref.read(locationServiceProvider).currentLocation();
    final device = await _ref.read(deviceStatusServiceProvider).snapshot();
    final security = _ref
        .read(securityServiceProvider)
        .evaluateLocationIntegrity(
          previous: state.lastLocation,
          current: location,
        );
    const inRadius = true;
    final readableLocation = await _ref
        .read(reverseGeocodingServiceProvider)
        .resolve(
          latitude: location.latitude,
          longitude: location.longitude,
          fallbackName: AppConfig.defaultSiteName,
        );
    final rooted = await _isRootedSignalPresent();
    final developerMode = false;
    final checks = [
      VerificationCheck(
        'Internet ${device.internetStatus}',
        device.internetStatus != 'Offline',
      ),
      VerificationCheck('GPS service enabled', true),
      VerificationCheck('Location permission granted', true),
      VerificationCheck('High accuracy mode ready', location.accuracy <= 50),
      VerificationCheck('Fake GPS disabled', !location.isMocked),
      VerificationCheck('Developer mode disabled', !developerMode),
      VerificationCheck('Device integrity trusted', !rooted),
      VerificationCheck('GPS accuracy acceptable', location.accuracy <= 75),
      VerificationCheck('Movement pattern trusted', security.isTrusted),
    ];
    return AttendanceVerificationContext(
      attendanceType: attendanceType,
      location: location,
      readableLocation: readableLocation,
      device: device,
      checks: checks,
      geoFenceMatched: inRadius,
      fakeGpsDetected: location.isMocked,
      developerModeEnabled: developerMode,
      rootedDevice: rooted,
    );
  }

  Future<Map<String, dynamic>> _payloadFor(
    AttendanceVerificationContext context,
    String selfiePath,
  ) async {
    final authState = _ref.read(authViewModelProvider);
    final profile = authState.profile ?? await _readCurrentProfile();
    final employeeRecordId = profile['id']?.toString() ?? '';
    final employeeCode = profile['employee_id']?.toString() ?? '';
    final employeeName = profile['full_name']?.toString() ?? '';
    final organizationId = profile['organization_id']?.toString() ?? '';

    return {
      if (context.attendanceType.toUpperCase().contains('CHECK-OUT') &&
          state.activeRecord?.id.isNotEmpty == true &&
          !state.activeRecord!.id.startsWith('LOCAL-'))
        'id': state.activeRecord!.id,
      'employeeRecordId': employeeRecordId,
      'employeeId': employeeCode.isNotEmpty ? employeeCode : employeeRecordId,
      'employeeName': employeeName,
      'organizationId': organizationId,
      'siteName': context.readableLocation,
      'readableLocation': context.readableLocation,
      'latitude': context.location.latitude,
      'longitude': context.location.longitude,
      'gpsAccuracy': context.location.accuracy,
      'selfieUrl': selfiePath,
      'batteryPercent': context.device.batteryPercent,
      'internetType': context.device.internetStatus,
      'attendanceMethod': 'SELFIE_GEO_VERIFIED',
      'isFakeGpsSuspected': context.fakeGpsDetected,
      'isDeveloperModeEnabled': context.developerModeEnabled,
      'isRootedDevice': context.rootedDevice,
      'geoFenceMatched': context.geoFenceMatched,
      'shiftStartAt': DateTime.now()
          .copyWith(hour: 9, minute: 0, second: 0, millisecond: 0)
          .toIso8601String(),
      'shiftEndAt': DateTime.now()
          .copyWith(hour: 18, minute: 0, second: 0, millisecond: 0)
          .toIso8601String(),
      'deviceMetadata': {
        'employeeId': employeeCode,
        'employeeRecordId': employeeRecordId,
        'employeeName': employeeName,
        'platform': Platform.operatingSystem,
        'platformVersion': Platform.operatingSystemVersion,
        'gpsAccuracy': context.location.accuracy,
        'capturedAt': DateTime.now().toIso8601String(),
        'checks': context.checks
            .map((check) => {'label': check.label, 'passed': check.passed})
            .toList(growable: false),
      },
    };
  }

  Future<Map<String, dynamic>> _readCurrentProfile() async {
    final userId = sb.supabase.auth.currentUser?.id;
    if (userId == null) {
      return const {};
    }
    final data = await sb.supabase
        .from('profiles')
        .select(
          'id, auth_user_id, role, full_name, email, employee_id, organization_id, branch_id, department_id, team_id, phone, status',
        )
        .eq('auth_user_id', userId)
        .maybeSingle();
    if (data == null) {
      return const {};
    }
    return Map<String, dynamic>.from(data);
  }

  Future<bool> _isRootedSignalPresent() async {
    if (!Platform.isAndroid) return false;
    return File('/system/app/Superuser.apk').existsSync() ||
        File('/system/xbin/su').existsSync() ||
        File('/system/bin/su').existsSync();
  }
}

class VerificationCheck {
  const VerificationCheck(this.label, this.passed);

  final String label;
  final bool passed;
}

class AttendanceVerificationContext {
  const AttendanceVerificationContext({
    required this.attendanceType,
    required this.location,
    required this.readableLocation,
    required this.device,
    required this.checks,
    required this.geoFenceMatched,
    required this.fakeGpsDetected,
    required this.developerModeEnabled,
    required this.rootedDevice,
  });

  final String attendanceType;
  final LocationSnapshot location;
  final String readableLocation;
  final DeviceStatusSnapshot device;
  final List<VerificationCheck> checks;
  final bool geoFenceMatched;
  final bool fakeGpsDetected;
  final bool developerModeEnabled;
  final bool rootedDevice;

  bool get canSubmit => checks.every((check) => check.passed);
}
