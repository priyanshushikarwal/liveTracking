import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/storage/offline_queue_service.dart';
import '../../../../core/services/media_storage_service.dart';
import '../../../../core/services/watermark_service.dart';
import '../../../../core/supabase/supabase_client.dart' as sb;
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    SupabaseClient? supabaseClient,
    OfflineQueueService? queueService,
    MediaStorageService? mediaStorage,
  }) : _supabase = supabaseClient ?? sb.supabase,
       _queueService = queueService,
       _mediaStorage = mediaStorage;

  final SupabaseClient _supabase;
  final OfflineQueueService? _queueService;
  final MediaStorageService? _mediaStorage;

  @override
  Future<AttendanceRecord> checkIn(Map<String, dynamic> payload) async {
    try {
      final prepared = await _prepareMediaPayload(payload);
      final databasePayload = _toDatabasePayload(prepared, isCheckIn: true);
      final response = await _supabase
          .from('attendance')
          .insert(databasePayload)
          .select()
          .single();
      return _fromJson(Map<String, dynamic>.from(response as Map));
    } catch (error) {
      await _queueService?.enqueue('attendance-check-in', payload);
      debugPrint('Attendance check-in failed: $error');
      throw Exception('Attendance upload failed. Please try again. $error');
    }
  }

  @override
  Future<AttendanceRecord> checkOut(Map<String, dynamic> payload) async {
    try {
      final prepared = await _prepareMediaPayload(payload);
      final databasePayload = _toDatabasePayload(prepared, isCheckIn: false);
      // Expecting payload to contain attendance id for update; otherwise insert
      if (databasePayload.containsKey('id')) {
        final id = databasePayload['id'];
        final updatePayload = Map<String, dynamic>.from(databasePayload)
          ..remove('id');
        final response = await _supabase
            .from('attendance')
            .update(updatePayload)
            .eq('id', id)
            .select()
            .single();
        return _fromJson(Map<String, dynamic>.from(response as Map));
      }
      final response =
          await (_supabase.from('attendance').insert(databasePayload).select()
                  as dynamic)
              .single();
      return _fromJson(Map<String, dynamic>.from(response as Map));
    } catch (error) {
      await _queueService?.enqueue('attendance-check-out', payload);
      debugPrint('Attendance check-out failed: $error');
      throw Exception('Check-out upload failed. Please try again. $error');
    }
  }

  Future<Map<String, dynamic>> _prepareMediaPayload(
    Map<String, dynamic> payload,
  ) async {
    final selfiePath = payload['selfieUrl'] as String?;
    if (selfiePath == null || selfiePath.isEmpty) return payload;
    if (selfiePath.startsWith('http') || selfiePath.startsWith('/uploads/')) {
      return payload;
    }

    try {
      final file = File(selfiePath);
      if (!await file.exists()) return payload;

      // Apply watermark to the selfie before upload
      final watermarkedFile = await _applyWatermark(file, payload: payload);
      final fileToUpload = watermarkedFile ?? file;

      // Upload to Supabase Storage
      final uploadedUrl = await _uploadSelfieToStorage(
        fileToUpload,
        payload: payload,
      );

      if (uploadedUrl != null) {
        return {
          ...payload,
          'selfieUrl': uploadedUrl,
          'checkInSelfieUrl': uploadedUrl,
        };
      }

      return payload;
    } catch (e) {
      debugPrint('Error preparing media payload: $e');
      return payload;
    }
  }

  Map<String, dynamic> _toDatabasePayload(
    Map<String, dynamic> payload, {
    required bool isCheckIn,
  }) {
    final now = DateTime.now();
    final employeeRecordId = payload['employeeRecordId']?.toString() ?? '';
    final organizationId = payload['organizationId']?.toString() ?? '';
    final latitude = (payload['latitude'] as num?)?.toDouble() ?? 0;
    final longitude = (payload['longitude'] as num?)?.toDouble() ?? 0;
    final readableLocation =
        payload['readableLocation'] as String? ??
        payload['siteName'] as String? ??
        'Verified field location';

    final data = <String, dynamic>{
      if (payload['id'] != null) 'id': payload['id'],
      'organization_id': organizationId.isNotEmpty ? organizationId : null,
      if (employeeRecordId.isNotEmpty) 'employee_id': employeeRecordId,
      'latitude': latitude,
      'longitude': longitude,
      'site_name': payload['siteName'] as String? ?? readableLocation,
      'readable_location': readableLocation,
      'selfie_url': payload['selfieUrl'],
      'gps_accuracy': (payload['gpsAccuracy'] as num?)?.toDouble(),
      'internet_type': payload['internetType'],
      'attendance_method':
          payload['attendanceMethod'] as String? ?? 'SELFIE_GEO_VERIFIED',
      'is_fake_gps_suspected': payload['isFakeGpsSuspected'] as bool? ?? false,
      'shift_start_at': payload['shiftStartAt'],
      'shift_end_at': payload['shiftEndAt'],
      'device_metadata': payload['deviceMetadata'],
      'confidence_score': payload['confidenceScore'] as int? ?? 90,
    };

    if (isCheckIn) {
      data.addAll({
        'check_in_at': payload['checkInAt'] ?? now.toIso8601String(),
        'check_in_selfie_url':
            payload['checkInSelfieUrl'] ?? payload['selfieUrl'],
        'status': 'CHECKED_IN',
      });
    } else {
      data.addAll({
        'check_out_at': payload['checkOutAt'] ?? now.toIso8601String(),
        'check_out_latitude': latitude,
        'check_out_longitude': longitude,
        'check_out_readable_location': readableLocation,
        'check_out_gps_accuracy': (payload['gpsAccuracy'] as num?)?.toDouble(),
        'check_out_selfie_url':
            payload['checkOutSelfieUrl'] ?? payload['selfieUrl'],
        'check_out_device_metadata': payload['deviceMetadata'],
        'status': 'CHECKED_OUT',
      });
    }

    data.removeWhere((_, value) => value == null);
    if (data['employee_id'] == null) {
      throw StateError('Employee profile is missing. Please log in again.');
    }
    return data;
  }

  /// Apply watermark with date, time, address, and GPS coordinates
  Future<File?> _applyWatermark(
    File imageFile, {
    required Map<String, dynamic> payload,
  }) async {
    try {
      final now = DateTime.now();
      final watermarkData = WatermarkData(
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        address:
            payload['readableLocation'] as String? ??
            payload['address'] as String? ??
            'Location',
        latitude: (payload['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (payload['longitude'] as num?)?.toDouble() ?? 0.0,
        accuracy:
            '${((payload['gpsAccuracy'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}m',
      );

      return await WatermarkService.addWatermark(imageFile, watermarkData);
    } catch (e) {
      debugPrint('Error applying watermark: $e');
      return null;
    }
  }

  /// Upload selfie to Supabase Storage with organized path structure
  Future<String?> _uploadSelfieToStorage(
    File imageFile, {
    required Map<String, dynamic> payload,
  }) async {
    try {
      final now = DateTime.now();
      final empId = payload['employeeId'] as String? ?? 'unknown';

      // Path structure: attendance/{empId}/{year}/{month}/{day}_{timestamp}.jpg
      final storagePath =
          'attendance/$empId/${now.year}/${now.month.toString().padLeft(2, '0')}/'
          '${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch}.jpg';

      // Prefer injected MediaStorageService if available
      if (_mediaStorage != null) {
        final uploaded = await _mediaStorage.uploadFile(
          imageFile,
          pathPrefix:
              'attendance/$empId/${now.year}/${now.month.toString().padLeft(2, '0')}/',
        );
        if (uploaded != null) return uploaded;
        // if media storage failed, fall back to direct upload
      }

      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage
      try {
        await _supabase.storage
            .from('uploads')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );

        // Get public URL
        final publicUrl = _supabase.storage
            .from('uploads')
            .getPublicUrl(storagePath);

        return publicUrl;
      } catch (e) {
        final msg = e.toString();
        // If storage RLS/permissions blocked the upload, queue the upload for later
        if (msg.contains('row-level security') ||
            msg.contains('statusCode: 403') ||
            msg.contains('Unauthorized')) {
          try {
            await _queueService?.enqueue('media-upload', {
              'type': 'selfie',
              'filePath': imageFile.path,
              'storagePath': storagePath,
              'payload': payload,
            });
          } catch (_) {}
          return 'LOCAL:${imageFile.path}';
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error uploading selfie to storage: $e');
      return null;
    }
  }

  @override
  Future<List<AttendanceRecord>> fetchHistory() async {
    final rows = await _supabase
        .from('attendance')
        .select()
        .order('check_in_at', ascending: false);
    return rows
        .map((row) => _fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  AttendanceRecord _fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      checkInTime:
          DateTime.tryParse(
            json['check_in_at'] as String? ??
                json['checkInAt'] as String? ??
                '',
          ) ??
          DateTime.now(),
      checkOutTime: (json['check_out_at'] ?? json['checkOutAt']) == null
          ? null
          : DateTime.tryParse(
              json['check_out_at'] as String? ??
                  json['checkOutAt'] as String? ??
                  '',
            ),
      siteName:
          json['site_name'] as String? ??
          json['siteName'] as String? ??
          'Verified field location',
      readableLocation:
          json['readableLocation'] as String? ??
          json['readable_location'] as String?,
      checkOutReadableLocation:
          json['check_out_readable_location'] as String? ??
          json['checkOutReadableLocation'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String? ?? 'CHECKED_IN').replaceAll('_', ' '),
      confidenceScore:
          (json['confidence_score'] as num?)?.toInt() ??
          (json['confidenceScore'] as num?)?.toInt() ??
          0,
      riskLevel:
          (json['risk_level'] as String? ??
                  json['riskLevel'] as String? ??
                  'MEDIUM')
              .replaceAll('_', ' '),
      verificationStatus:
          (json['verification_status'] as String? ??
                  json['verificationStatus'] as String? ??
                  'LOW_CONFIDENCE')
              .replaceAll('_', ' '),
      gpsAccuracy:
          (json['gps_accuracy'] as num?)?.toDouble() ??
          (json['gpsAccuracy'] as num?)?.toDouble(),
      internetType:
          json['internet_type'] as String? ?? json['internetType'] as String?,
      batteryPercent:
          (json['battery_percent'] as num?)?.toInt() ??
          (json['batteryPercent'] as num?)?.toInt(),
      checkInSelfieUrl:
          json['check_in_selfie_url'] as String? ??
          json['checkInSelfieUrl'] as String? ??
          json['selfie_url'] as String? ??
          json['selfieUrl'] as String?,
      checkOutSelfieUrl:
          json['check_out_selfie_url'] as String? ??
          json['checkOutSelfieUrl'] as String?,
      workDurationMinutes:
          (json['work_duration_minutes'] as num?)?.toInt() ??
          (json['workDurationMinutes'] as num?)?.toInt(),
      distanceTravelledMeters:
          (json['distance_travelled_meters'] as num?)?.toDouble() ??
          (json['distanceTravelledMeters'] as num?)?.toDouble(),
      totalVisits:
          (json['total_visits'] as num?)?.toInt() ??
          (json['totalVisits'] as num?)?.toInt(),
      productivityScore:
          (json['productivity_score'] as num?)?.toInt() ??
          (json['productivityScore'] as num?)?.toInt(),
    );
  }
}
