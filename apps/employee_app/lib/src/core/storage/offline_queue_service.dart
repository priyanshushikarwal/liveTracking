import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';

final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  return const OfflineQueueService();
});

class OfflineQueueService {
  const OfflineQueueService();

  Future<Box<String>> _openBox() =>
      Hive.openBox<String>(AppConstants.hiveQueueBox);

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    final box = await _openBox();
    await box.add(jsonEncode({'type': type, 'payload': payload}));
  }

  Future<List<Map<String, dynamic>>> drain() async {
    final box = await _openBox();
    final items = box.values
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .toList(growable: false);
    await box.clear();
    return items;
  }

  Future<int> pendingCount() async {
    final box = await _openBox();
    return box.length;
  }
}
