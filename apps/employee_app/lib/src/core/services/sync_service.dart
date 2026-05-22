import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/dio_client.dart';
import '../storage/offline_queue_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    dio: ref.watch(dioProvider),
    queueService: ref.watch(offlineQueueProvider),
  );
});

class SyncService {
  const SyncService({
    required Dio dio,
    required OfflineQueueService queueService,
  }) : _dio = dio,
       _queueService = queueService;

  final Dio _dio;
  final OfflineQueueService _queueService;

  Future<SyncSummary> syncQueuedRequests() async {
    final items = await _queueService.drain();
    if (items.isEmpty) {
      return const SyncSummary(processed: 0, failed: 0);
    }

    if (AppConfig.useDemoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return SyncSummary(processed: items.length, failed: 0);
    }

    var processed = 0;
    var failed = 0;
    for (final item in items) {
      try {
        final payload = Map<String, dynamic>.from(item['payload'] as Map);
        await _dio.post(
          _endpointFor(item['type'] as String? ?? 'unknown'),
          data: payload,
        );
        processed++;
      } catch (_) {
        failed++;
        await _queueService.enqueue(
          item['type'] as String? ?? 'unknown',
          Map<String, dynamic>.from(item['payload'] as Map? ?? const {}),
        );
      }
    }

    return SyncSummary(processed: processed, failed: failed);
  }

  String _endpointFor(String type) {
    switch (type) {
      case 'tracking':
        return '/tracking/ingest';
      case 'attendance-check-in':
        return '/attendance/check-in';
      case 'attendance-check-out':
        return '/attendance/check-out';
      case 'visit-start':
        return '/visits/${type.split(':').last}/start';
      default:
        return '/tracking/ingest';
    }
  }
}

class SyncSummary {
  const SyncSummary({required this.processed, required this.failed});

  final int processed;
  final int failed;
}
