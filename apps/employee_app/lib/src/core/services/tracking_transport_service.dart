import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/offline_queue_service.dart';
import '../storage/secure_storage_service.dart';
import '../supabase/supabase_client.dart' as sb;

final trackingTransportServiceProvider = Provider<TrackingTransportService>((
  ref,
) {
  final service = TrackingTransportService(
    supabase: sb.supabase,
    queueService: ref.watch(offlineQueueProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

enum TrackingTransportConnectionState { connecting, connected, disconnected }

class TrackingDeliveryResult {
  const TrackingDeliveryResult({
    required this.delivered,
    required this.queued,
    required this.viaSocket,
    this.receivedAt,
    this.message,
  });

  final bool delivered;
  final bool queued;
  final bool viaSocket;
  final DateTime? receivedAt;
  final String? message;
}

class TrackingServerUpdate {
  const TrackingServerUpdate({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.recordedAt,
    required this.trackingStatus,
    required this.isOnline,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime recordedAt;
  final String trackingStatus;
  final bool isOnline;
}

class TrackingPayload {
  const TrackingPayload({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.batteryPercent,
    required this.internetStatus,
    required this.recordedAt,
    required this.activity,
    required this.isMocked,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final int batteryPercent;
  final String internetStatus;
  final DateTime recordedAt;
  final String activity;
  final bool isMocked;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'bearing': heading,
      'battery_percent': batteryPercent,
      'internet_status': internetStatus,
      'recorded_at': recordedAt.toIso8601String(),
      'activity': activity,
      'is_mocked': isMocked,
    };
  }
}

class TrackingTransportService {
  TrackingTransportService({
    required SupabaseClient supabase,
    required OfflineQueueService queueService,
    required SecureStorageService secureStorage,
  }) : _supabase = supabase,
       _queueService = queueService,
       _secureStorage = secureStorage;

  final SupabaseClient _supabase;
  final OfflineQueueService _queueService;
  final SecureStorageService _secureStorage;

  final _connectionController =
      StreamController<TrackingTransportConnectionState>.broadcast();
  final _serverUpdateController =
      StreamController<TrackingServerUpdate>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Timer? _heartbeatTimer;
  String? _organizationId;
  String? _employeeId;
  String? _employeeName;
  bool _disposed = false;
  bool _initialized = false;
  bool _flushingQueue = false;

  Stream<TrackingTransportConnectionState> get connectionStream =>
      _connectionController.stream;
  Stream<TrackingServerUpdate> get serverUpdateStream =>
      _serverUpdateController.stream;
  Stream<String> get statusStream => _statusController.stream;

  TrackingTransportConnectionState get currentConnectionState =>
      TrackingTransportConnectionState.connected;

  Future<void> initialize() async {
    if (_disposed) return;
    if (_initialized) return;
    final session = await _secureStorage.readSession();
    _employeeId = session?.employee.id;
    _organizationId = session?.employee.organizationId;
    _employeeName = session?.employee.name;
    if (_employeeId == null || _employeeId!.isEmpty) {
      await _resolveIdentityFromSupabaseSession();
    }
    debugPrint(
      '[TrackingDebug] transport initialized employee=$_employeeId org=$_organizationId name=$_employeeName',
    );
    _initialized = true;
    if (!_flushingQueue) {
      await flushQueue();
    }
  }

  Future<void> _resolveIdentityFromSupabaseSession() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('id, organization_id, full_name, email')
          .eq('auth_user_id', userId)
          .maybeSingle();
      if (profile == null) {
        return;
      }

      _employeeId = profile['id']?.toString();
      _organizationId = profile['organization_id']?.toString();
      _employeeName =
          profile['full_name']?.toString() ?? profile['email']?.toString();
    } catch (_) {
      // Keep the publish path queue-first if identity lookup is unavailable.
    }
  }

  Future<TrackingDeliveryResult> publishLocation(
    TrackingPayload payload, {
    bool allowQueue = true,
  }) async {
    await initialize();
    final data = payload.toJson();
    if (_employeeId != null && _employeeId!.isNotEmpty) {
      data['employee_id'] = _employeeId;
    }
    if (_organizationId != null && _organizationId!.isNotEmpty) {
      data['organization_id'] = _organizationId;
    }
    final enrichedData = {
      ...data,
      if (_employeeName != null && _employeeName!.isNotEmpty)
        'employee_name': _employeeName,
      'tracking_status': payload.activity,
      'network_status': payload.internetStatus,
      'timestamp': payload.recordedAt.toIso8601String(),
    };

    try {
      debugPrint(
        '[TrackingDebug] uploading location employee=${data['employee_id']} lat=${payload.latitude} lng=${payload.longitude} status=${payload.activity}',
      );
      final rows =
          await _insertTrackingRow('live_locations', enrichedData, data) ??
          const [];
      debugPrint(
        '[TrackingDebug] location uploaded live_locations rows=${rows.length}',
      );
      try {
        final Map<String, dynamic> historyData = {
          'latitude': payload.latitude,
          'longitude': payload.longitude,
          'accuracy': payload.accuracy,
          'speed': payload.speed,
          'battery_percent': payload.batteryPercent,
          'internet_status': payload.internetStatus,
          'recorded_at': payload.recordedAt.toIso8601String(),
          'activity': payload.activity,
          'is_mocked': payload.isMocked,
        };
        if (_employeeId != null && _employeeId!.isNotEmpty) {
          historyData['employee_id'] = _employeeId;
        }
        if (_organizationId != null && _organizationId!.isNotEmpty) {
          historyData['organization_id'] = _organizationId;
        }

        await _insertTrackingRow('location_history', historyData, historyData);
        debugPrint('[TrackingDebug] location history inserted');
      } catch (e) {
        debugPrint('[TrackingDebug] location history insert failed: $e');
        // Live tracking should still succeed if history persistence is delayed.
      }
      final first = rows.isNotEmpty
          ? Map<String, dynamic>.from(rows.first as Map)
          : <String, dynamic>{};
      final recordedAt =
          DateTime.tryParse(first['recorded_at'] as String? ?? '') ??
          payload.recordedAt;
      // Emit server update for local listeners
      _serverUpdateController.add(
        TrackingServerUpdate(
          latitude: (first['latitude'] as num?)?.toDouble() ?? payload.latitude,
          longitude:
              (first['longitude'] as num?)?.toDouble() ?? payload.longitude,
          accuracy: (first['accuracy'] as num?)?.toDouble() ?? payload.accuracy,
          speed: (first['speed'] as num?)?.toDouble() ?? payload.speed,
          heading: (first['bearing'] as num?)?.toDouble() ?? payload.heading,
          recordedAt: recordedAt,
          trackingStatus: payload.activity,
          isOnline: true,
        ),
      );
      _statusController.add(payload.activity);
      return TrackingDeliveryResult(
        delivered: true,
        queued: false,
        viaSocket: false,
        receivedAt: recordedAt,
      );
    } catch (error) {
      debugPrint('[TrackingDebug] location upload failed: $error');
      if (allowQueue) {
        await _queueService.enqueue('tracking', data);
        debugPrint('[TrackingDebug] location queued for retry');
      }
      return const TrackingDeliveryResult(
        delivered: false,
        queued: true,
        viaSocket: false,
      );
    }
  }

  Future<void> pushStatusChange(String status) async {
    await initialize();
    try {
      if (_employeeId != null && _employeeId!.isNotEmpty) {
        await _supabase
            .from('employees')
            .update({'current_activity': status})
            .eq('id', _employeeId!);
      }
      _statusController.add(status);
    } catch (_) {}
  }

  Future<List<dynamic>?> _insertTrackingRow(
    String table,
    Map<String, dynamic> enrichedData,
    Map<String, dynamic> fallbackData,
  ) async {
    try {
      final query = _supabase.from(table).insert(enrichedData);
      if (table == 'live_locations') {
        return await query.select() as List<dynamic>?;
      }
      await query;
      return null;
    } catch (error) {
      debugPrint(
        '[TrackingDebug] $table enriched insert failed, retrying compatible payload: $error',
      );
      final query = _supabase.from(table).insert(fallbackData);
      if (table == 'live_locations') {
        return await query.select() as List<dynamic>?;
      }
      await query;
      return null;
    }
  }

  Future<void> flushQueue() async {
    if (_flushingQueue) return;
    _flushingQueue = true;
    final items = await _queueService.drain();
    if (items.isEmpty) {
      _flushingQueue = false;
      return;
    }

    try {
      for (final item in items) {
        final payload = Map<String, dynamic>.from(
          item['payload'] as Map? ?? const {},
        );
        final result = await publishLocation(
          TrackingPayload(
            latitude: (payload['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (payload['longitude'] as num?)?.toDouble() ?? 0,
            accuracy: (payload['accuracy'] as num?)?.toDouble() ?? 0,
            speed: (payload['speed'] as num?)?.toDouble() ?? 0,
            heading: (payload['bearing'] as num?)?.toDouble() ?? 0,
            batteryPercent:
                (payload['battery_percent'] as num?)?.toInt() ??
                (payload['batteryPercent'] as num?)?.toInt() ??
                0,
            internetStatus:
                payload['internet_status'] as String? ??
                payload['internetStatus'] as String? ??
                'Unknown',
            recordedAt:
                DateTime.tryParse(
                  payload['recorded_at'] as String? ??
                      payload['recordedAt'] as String? ??
                      '',
                ) ??
                DateTime.now(),
            activity: payload['activity'] as String? ?? 'ACTIVE',
            isMocked:
                payload['is_mocked'] as bool? ??
                payload['isMocked'] as bool? ??
                false,
          ),
          allowQueue: false,
        );

        if (!result.delivered) {
          await _queueService.enqueue('tracking', payload);
        }
      }
    } finally {
      _flushingQueue = false;
    }
  }

  void dispose() {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _connectionController.close();
    _serverUpdateController.close();
    _statusController.close();
  }
}
