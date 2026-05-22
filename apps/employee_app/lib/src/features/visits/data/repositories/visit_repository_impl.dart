import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/supabase/supabase_client.dart' as sb;
import '../../domain/entities/employee_visit.dart';

class VisitRepositoryImpl {
  VisitRepositoryImpl({SupabaseClient? supabaseClient})
    : _supabase = supabaseClient ?? sb.supabase;

  final SupabaseClient _supabase;

  final List<EmployeeVisit> _visits = [
    EmployeeVisit(
      id: 'VIS-101',
      clientName: 'Metro Retail LLP',
      contactPerson: 'Aarav Mehta',
      phone: '+91 98765 43210',
      email: 'ops@metroretail.example',
      siteAddress: 'Sector 62, Noida',
      visitType: 'Solar Site Inspection',
      priority: 'High',
      objective: 'Solar Site Inspection',
      latitude: AppConfig.defaultSiteLatitude,
      longitude: AppConfig.defaultSiteLongitude,
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      status: 'Pending',
      distanceMeters: 45,
    ),
    EmployeeVisit(
      id: 'VIS-102',
      clientName: 'Zenith Buildcon',
      contactPerson: 'Sara Khan',
      phone: '+91 98765 11223',
      siteAddress: 'Cyber City, Gurugram',
      visitType: 'Service Follow-up',
      priority: 'Medium',
      scheduledAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      endTime: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      status: 'Completed',
      outcome: 'Service Completed',
      notes: 'Installed branding material and submitted photos.',
      productivityScore: 86,
    ),
  ];

  Future<List<EmployeeVisit>> fetchAssignedVisits() async {
    if (AppConfig.useDemoMode) return List.unmodifiable(_visits);
    try {
      final profileId = await _currentProfileId();
      var query = _supabase.from('visits').select(_visitSelect);
      if (profileId != null) query = query.eq('employee_id', profileId);
      final rows = await query.order('scheduled_at', ascending: true);
      return (rows as List<dynamic>)
          .map((row) => _fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } catch (_) {
      return List.unmodifiable(_visits);
    }
  }

  Future<EmployeeVisit> startVisit(
    String visitId, {
    required double latitude,
    required double longitude,
    required double accuracy,
    required int batteryPercent,
    required String networkType,
    required bool fakeGpsDetected,
  }) async {
    if (!AppConfig.useDemoMode) {
      final payload = {
        'started_at': DateTime.now().toIso8601String(),
        'status': 'STARTED',
        'start_lat': latitude,
        'start_lng': longitude,
        'gps_accuracy': accuracy,
        'battery_percent': batteryPercent,
        'network_type': networkType,
        'device_metadata': {
          'source': 'employee_app',
          'fake_gps_detected': fakeGpsDetected,
        },
      };
      final row = await _supabase
          .from('visits')
          .update(payload)
          .eq('id', visitId)
          .select(_visitSelect)
          .single();
      await _logActivity(visitId, 'started', 'Visit started on site.');
      return _fromJson(Map<String, dynamic>.from(row));
    }
    final index = _demoIndex(visitId);
    final updated = _visits[index].copyWith(
      startedAt: DateTime.now(),
      status: 'In Progress',
    );
    _visits[index] = updated;
    return updated;
  }

  Future<EmployeeVisit> saveNotes(String visitId, String notes) async {
    if (!AppConfig.useDemoMode) {
      await _supabase.from('visit_notes').insert({
        'visit_id': visitId,
        'note': notes,
        'note_format': 'plain_text',
        'is_draft': false,
      });
      final row = await _supabase
          .from('visits')
          .update({'notes': notes})
          .eq('id', visitId)
          .select(_visitSelect)
          .single();
      await _logActivity(visitId, 'note_added', 'Visit notes updated.');
      return _fromJson(Map<String, dynamic>.from(row));
    }
    final index = _demoIndex(visitId);
    final updated = _visits[index].copyWith(notes: notes);
    _visits[index] = updated;
    return updated;
  }

  Future<EmployeeVisit> addFollowUp({
    required String visitId,
    required DateTime date,
    required String priority,
    required String notes,
  }) async {
    if (!AppConfig.useDemoMode) {
      await _supabase.from('visit_followups').insert({
        'visit_id': visitId,
        'followup_date': date.toIso8601String(),
        'priority': priority.toUpperCase(),
        'notes': notes,
      });
      await _logActivity(visitId, 'followup_created', 'Follow-up created.');
      return _reloadVisit(visitId);
    }
    final index = _demoIndex(visitId);
    final updated = _visits[index].copyWith(
      followUps: [
        ..._visits[index].followUps,
        VisitFollowUp(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: date,
          priority: priority,
          notes: notes,
        ),
      ],
    );
    _visits[index] = updated;
    return updated;
  }

  Future<EmployeeVisit> uploadPhoto({
    required String visitId,
    required File file,
    required String category,
    required double latitude,
    required double longitude,
  }) async {
    if (!AppConfig.useDemoMode) {
      final path =
          'photos/$visitId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (!await file.exists()) {
        throw Exception('Captured photo file was not found.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Captured photo file is empty.');
      }
      try {
        await _supabase.storage
            .from('visit-media')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      } catch (error) {
        throw Exception('Visit photo upload failed: $error');
      }
      final url = _supabase.storage.from('visit-media').getPublicUrl(path);
      await _supabase
          .from('visits')
          .update({'image_url': url})
          .eq('id', visitId);
      await _supabase.from('visit_photos').insert({
        'visit_id': visitId,
        'category': category,
        'storage_path': path,
        'public_url': url,
        'latitude': latitude,
        'longitude': longitude,
        'readable_location':
            '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      });
      await _logActivity(visitId, 'photo_added', '$category photo uploaded.');
      return _reloadVisit(visitId);
    }
    final index = _demoIndex(visitId);
    final updated = _visits[index].copyWith(
      photos: [
        ..._visits[index].photos,
        VisitAttachment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: category,
          category: category,
          url: file.path,
          createdAt: DateTime.now(),
        ),
      ],
    );
    _visits[index] = updated;
    return updated;
  }

  Future<EmployeeVisit> submitFieldVisit({
    required FieldVisitDraft draft,
    required double latitude,
    required double longitude,
    required double accuracy,
    required int batteryPercent,
    required String networkType,
    File? photo,
    String photoCategory = 'Site Photo',
  }) async {
    final now = DateTime.now();
    if (!AppConfig.useDemoMode) {
      final profileId = await _currentProfileId();
      final orgId = await _currentProfileOrgId();
      final payload = {
        'organization_id': orgId,
        'employee_id': profileId,
        'client_name': draft.clientName,
        'site_name': draft.clientName,
        'site_address': draft.address.isEmpty
            ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
            : draft.address,
        'contact_person': draft.contactPerson,
        'phone': draft.phone,
        'email': draft.email,
        'visit_type': draft.visitType,
        'priority': draft.priority.toUpperCase(),
        'objective': draft.objective,
        'scheduled_at': now.toIso8601String(),
        'started_at': now.toIso8601String(),
        'ended_at': now.toIso8601String(),
        'start_lat': latitude,
        'start_lng': longitude,
        'end_lat': latitude,
        'end_lng': longitude,
        'client_lat': latitude,
        'client_lng': longitude,
        'gps_accuracy': accuracy,
        'battery_percent': batteryPercent,
        'network_type': networkType,
        'notes': draft.notes,
        'outcome': draft.outcome,
        'status': 'COMPLETED',
        'productivity_score': _productivityScore(
          notes: draft.notes,
          outcome: draft.outcome,
        ),
        'device_metadata': {'source': 'employee_field_visit_submit'},
      };
      final row = await _supabase
          .from('visits')
          .insert(payload)
          .select(_visitSelect)
          .single();
      final visit = _fromJson(Map<String, dynamic>.from(row));

      await _supabase.from('visit_notes').insert({
        'visit_id': visit.id,
        'note': draft.notes,
        'note_format': 'plain_text',
        'is_draft': false,
      });
      await _supabase.from('visit_outcomes').insert({
        'visit_id': visit.id,
        'outcome': draft.outcome,
        'notes': draft.notes,
      });
      await _logActivity(
        visit.id,
        'field_visit_submitted',
        'Employee submitted a field visit from GPS location.',
      );
      if (photo != null) {
        await uploadPhoto(
          visitId: visit.id,
          file: photo,
          category: photoCategory,
          latitude: latitude,
          longitude: longitude,
        );
      }
      await _upsertLiveLocation(
        organizationId: orgId,
        employeeId: profileId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        batteryPercent: batteryPercent,
        networkType: networkType,
      );
      return _reloadVisit(visit.id);
    }

    final visit = EmployeeVisit(
      id: 'VIS-${now.microsecondsSinceEpoch}',
      clientName: draft.clientName,
      contactPerson: draft.contactPerson,
      phone: draft.phone,
      email: draft.email,
      siteAddress: draft.address.isEmpty
          ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
          : draft.address,
      visitType: draft.visitType,
      priority: draft.priority,
      objective: draft.objective,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: 0,
      scheduledAt: now,
      startedAt: now,
      endTime: now,
      status: 'Completed',
      notes: draft.notes,
      outcome: draft.outcome,
      productivityScore: _productivityScore(
        notes: draft.notes,
        outcome: draft.outcome,
      ),
      photos: photo == null
          ? const []
          : [
              VisitAttachment(
                id: now.microsecondsSinceEpoch.toString(),
                label: photoCategory,
                category: photoCategory,
                url: photo.path,
                createdAt: now,
                readableLocation:
                    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
              ),
            ],
    );
    _visits.insert(0, visit);
    return visit;
  }

  Future<EmployeeVisit> uploadSignature({
    required String visitId,
    required Uint8List pngBytes,
  }) async {
    if (!AppConfig.useDemoMode) {
      final path =
          'signatures/$visitId/${DateTime.now().millisecondsSinceEpoch}.png';
      await _supabase.storage.from('visit-media').uploadBinary(path, pngBytes);
      await _supabase.from('visit_signatures').insert({
        'visit_id': visitId,
        'storage_path': path,
        'public_url': _supabase.storage.from('visit-media').getPublicUrl(path),
      });
      await _logActivity(
        visitId,
        'signature_added',
        'Customer signature saved.',
      );
      return _reloadVisit(visitId);
    }
    return _visits[_demoIndex(visitId)];
  }

  Future<EmployeeVisit> endVisit({
    required String visitId,
    required String notes,
    required String outcome,
    required double latitude,
    required double longitude,
  }) async {
    final score = _productivityScore(notes: notes, outcome: outcome);
    if (!AppConfig.useDemoMode) {
      await saveNotes(visitId, notes);
      await _supabase.from('visit_outcomes').insert({
        'visit_id': visitId,
        'outcome': outcome,
        'notes': notes,
      });
      final row = await _supabase
          .from('visits')
          .update({
            'ended_at': DateTime.now().toIso8601String(),
            'status': 'COMPLETED',
            'end_lat': latitude,
            'end_lng': longitude,
            'notes': notes,
            'outcome': outcome,
            'productivity_score': score,
          })
          .eq('id', visitId)
          .select(_visitSelect)
          .single();
      await _logActivity(visitId, 'completed', 'Visit completed: $outcome.');
      return _fromJson(Map<String, dynamic>.from(row));
    }
    final index = _demoIndex(visitId);
    final updated = _visits[index].copyWith(
      endTime: DateTime.now(),
      status: 'Completed',
      notes: notes,
      outcome: outcome,
      productivityScore: score,
    );
    _visits[index] = updated;
    return updated;
  }

  Future<String?> _currentProfileId() async {
    try {
      final id = await _supabase.rpc('current_profile_id');
      return id?.toString();
    } catch (_) {
      return _supabase.auth.currentUser?.id;
    }
  }

  Future<String?> _currentProfileOrgId() async {
    try {
      final id = await _supabase.rpc('current_profile_org_id');
      return id?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertLiveLocation({
    required String? organizationId,
    required String? employeeId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required int batteryPercent,
    required String networkType,
  }) async {
    if (employeeId == null || employeeId.isEmpty) return;
    try {
      await _supabase.from('live_locations').insert({
        'organization_id': organizationId,
        'employee_id': employeeId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'battery_percent': batteryPercent,
        'internet_status': networkType,
        'activity': 'Visit Submitted',
        'recorded_at': DateTime.now().toIso8601String(),
      });
      await _supabase.from('location_history').insert({
        'organization_id': organizationId,
        'employee_id': employeeId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'distance_meters': 0,
        'activity': 'Visit Submitted',
        'battery_percent': batteryPercent,
        'internet_status': networkType,
        'recorded_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<EmployeeVisit> _reloadVisit(String visitId) async {
    final row = await _supabase
        .from('visits')
        .select(_visitSelect)
        .eq('id', visitId)
        .single();
    return _fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> _logActivity(String visitId, String type, String message) async {
    try {
      await _supabase.from('visit_activities').insert({
        'visit_id': visitId,
        'activity_type': type,
        'message': message,
      });
    } catch (_) {}
  }

  int _demoIndex(String visitId) {
    final index = _visits.indexWhere((visit) => visit.id == visitId);
    if (index == -1) throw Exception('Visit not found.');
    return index;
  }

  int _productivityScore({required String notes, required String outcome}) {
    var score = 45;
    if (notes.trim().length > 40) score += 15;
    if (outcome.toLowerCase().contains('approved') ||
        outcome.toLowerCase().contains('completed')) {
      score += 25;
    } else if (outcome.toLowerCase().contains('follow')) {
      score += 15;
    }
    return score.clamp(0, 100);
  }

  EmployeeVisit _fromJson(Map<String, dynamic> json) {
    final client = Map<String, dynamic>.from(json['clients'] as Map? ?? {});
    final photos = _attachments(json['visit_photos'], defaultLabel: 'Photo');
    final documents = _attachments(
      json['visit_documents'],
      defaultLabel: 'Document',
    );
    final audio = _attachments(
      json['visit_audio_notes'],
      defaultLabel: 'Voice note',
    );
    final scheduledAt = json['scheduled_at'] as String?;
    final startedAt = json['started_at'] as String?;
    final endedAt = json['ended_at'] as String?;
    return EmployeeVisit(
      id: json['id'] as String? ?? '',
      clientId: json['client_id'] as String?,
      organizationId: json['organization_id'] as String?,
      clientName:
          client['company_name'] as String? ??
          json['client_name'] as String? ??
          'Client',
      contactPerson:
          client['contact_person'] as String? ??
          json['contact_person'] as String? ??
          'Primary contact',
      phone: client['phone'] as String? ?? json['phone'] as String? ?? '',
      email: client['email'] as String? ?? json['email'] as String? ?? '',
      siteAddress:
          client['address'] as String? ??
          json['site_address'] as String? ??
          json['site_name'] as String? ??
          'Field Site',
      visitType: json['visit_type'] as String? ?? 'Client Visit',
      priority: _label(json['priority'] as String? ?? 'MEDIUM'),
      clientType: client['client_type'] as String? ?? 'Enterprise',
      clientCategory: client['category'] as String? ?? 'General',
      assignedBy: json['assigned_by_name'] as String? ?? 'Admin',
      objective: json['objective'] as String? ?? 'Client meeting',
      latitude:
          (json['client_lat'] as num?)?.toDouble() ??
          (client['latitude'] as num?)?.toDouble(),
      longitude:
          (json['client_lng'] as num?)?.toDouble() ??
          (client['longitude'] as num?)?.toDouble(),
      allowedRadiusMeters:
          (json['allowed_radius_meters'] as num?)?.toDouble() ?? 120,
      distanceMeters: (json['verification_distance'] as num?)?.toDouble(),
      scheduledAt: DateTime.tryParse(scheduledAt ?? '') ?? DateTime.now(),
      startedAt: DateTime.tryParse(startedAt ?? ''),
      endTime: DateTime.tryParse(endedAt ?? ''),
      status: _statusLabel(json['status'] as String? ?? 'ASSIGNED'),
      notes: json['notes'] as String? ?? '',
      outcome: json['outcome'] as String?,
      productivityScore: (json['productivity_score'] as num?)?.toInt() ?? 0,
      photos: photos,
      documents: documents,
      audioNotes: audio,
      followUps: _followUps(json['visit_followups']),
      activities: _activities(json['visit_activities']),
    );
  }

  List<VisitAttachment> _attachments(
    Object? rows, {
    required String defaultLabel,
  }) {
    return (rows as List<dynamic>? ?? const [])
        .map((row) {
          final json = Map<String, dynamic>.from(row as Map);
          return VisitAttachment(
            id: json['id'] as String? ?? '',
            label:
                json['title'] as String? ??
                json['category'] as String? ??
                defaultLabel,
            category: json['category'] as String? ?? defaultLabel,
            url:
                json['public_url'] as String? ??
                json['storage_path'] as String? ??
                '',
            createdAt:
                DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
            readableLocation: json['readable_location'] as String?,
          );
        })
        .toList(growable: false);
  }

  List<VisitFollowUp> _followUps(Object? rows) {
    return (rows as List<dynamic>? ?? const [])
        .map((row) {
          final json = Map<String, dynamic>.from(row as Map);
          return VisitFollowUp(
            id: json['id'] as String? ?? '',
            date:
                DateTime.tryParse(json['followup_date'] as String? ?? '') ??
                DateTime.now(),
            priority: _label(json['priority'] as String? ?? 'MEDIUM'),
            notes: json['notes'] as String? ?? '',
            completed: json['completed_at'] != null,
          );
        })
        .toList(growable: false);
  }

  List<VisitActivity> _activities(Object? rows) {
    return (rows as List<dynamic>? ?? const [])
        .map((row) {
          final json = Map<String, dynamic>.from(row as Map);
          return VisitActivity(
            id: json['id'] as String? ?? '',
            type: json['activity_type'] as String? ?? 'activity',
            message: json['message'] as String? ?? '',
            createdAt:
                DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
          );
        })
        .toList(growable: false);
  }

  String _statusLabel(String value) {
    switch (value.toUpperCase()) {
      case 'STARTED':
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
      case 'VERIFIED':
        return 'Completed';
      case 'MISSED':
        return 'Missed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'RESCHEDULED':
        return 'Rescheduled';
      default:
        return 'Pending';
    }
  }

  String _label(String value) {
    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

const _visitSelect = '''
*,
clients(*),
visit_photos(*),
visit_documents(*),
visit_audio_notes(*),
visit_followups!visit_followups_visit_id_fkey(*),
visit_activities(*)
''';
