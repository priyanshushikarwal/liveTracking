import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client.dart' as sb;

final mediaStorageProvider = Provider<MediaStorageService>((ref) {
  return MediaStorageService(supabase: sb.supabase, bucket: 'uploads');
});

class MediaStorageService {
  MediaStorageService({required SupabaseClient supabase, required this.bucket})
    : _supabase = supabase;

  final SupabaseClient _supabase;
  final String bucket;

  Future<String?> uploadFile(File file, {String? pathPrefix}) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = file.path.split('/').last;
      final destPath =
          '${pathPrefix ?? ''}${DateTime.now().millisecondsSinceEpoch}_$filename';
      await (_supabase.storage.from(bucket).uploadBinary(destPath, bytes)
          as dynamic);
      return _supabase.storage.from(bucket).getPublicUrl(destPath);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getPublicUrl(String path) async {
    try {
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}
