import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/device_status_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/security_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/employee_visit.dart';

class VisitState {
  const VisitState({
    this.loading = false,
    this.visits = const [],
    this.query = '',
    this.statusFilter = 'All',
    this.priorityFilter = 'All',
    this.message,
    this.error,
  });

  final bool loading;
  final List<EmployeeVisit> visits;
  final String query;
  final String statusFilter;
  final String priorityFilter;
  final String? message;
  final String? error;

  List<EmployeeVisit> get filteredVisits {
    final q = query.trim().toLowerCase();
    final filtered = visits.where((visit) {
      final matchesQuery =
          q.isEmpty ||
          visit.clientName.toLowerCase().contains(q) ||
          visit.contactPerson.toLowerCase().contains(q) ||
          visit.phone.toLowerCase().contains(q);
      final matchesStatus =
          statusFilter == 'All' || visit.status == statusFilter;
      final matchesPriority =
          priorityFilter == 'All' || visit.priority == priorityFilter;
      return matchesQuery && matchesStatus && matchesPriority;
    }).toList();
    filtered.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return filtered;
  }

  VisitState copyWith({
    bool? loading,
    List<EmployeeVisit>? visits,
    String? query,
    String? statusFilter,
    String? priorityFilter,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return VisitState(
      loading: loading ?? this.loading,
      visits: visits ?? this.visits,
      query: query ?? this.query,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class VisitViewModel extends StateNotifier<VisitState> {
  VisitViewModel(this._ref) : super(const VisitState());

  final Ref _ref;
  LocationSnapshot? _lastLocation;

  Future<void> loadVisits() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final visits = await _ref
          .read(visitRepositoryProvider)
          .fetchAssignedVisits();
      final enriched = await _withDistance(visits);
      state = state.copyWith(loading: false, visits: enriched);
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  void setSearch(String value) => state = state.copyWith(query: value);

  void setStatusFilter(String value) {
    state = state.copyWith(statusFilter: value);
  }

  void setPriorityFilter(String value) {
    state = state.copyWith(priorityFilter: value);
  }

  Future<String> validateStart(EmployeeVisit visit) async {
    try {
      final locationService = _ref.read(locationServiceProvider);
      final gpsEnabled = await locationService.isServiceEnabled();
      final permission = await locationService.ensurePermission();
      final current = await locationService.currentLocation();
      final security = _ref
          .read(securityServiceProvider)
          .evaluateLocationIntegrity(previous: _lastLocation, current: current);
      _lastLocation = current;
      final distance = _distanceToVisit(visit, current);
      final permissionName = permission.name.toLowerCase();
      final allowed =
          gpsEnabled &&
          (permissionName.contains('whileinuse') ||
              permissionName.contains('always'));
      if (!allowed) return 'Location permission is required.';
      if (!security.isTrusted) return security.reasons.join('\n');
      if (distance != null && distance > visit.allowedRadiusMeters) {
        return 'Move within ${visit.allowedRadiusMeters.toStringAsFixed(0)} meters. Current distance: ${distance.toStringAsFixed(0)} meters.';
      }
      return 'Distance: ${(distance ?? 0).toStringAsFixed(0)} meters\nVisit Start Allowed';
    } catch (error) {
      return '$error'.replaceFirst('Exception: ', '');
    }
  }

  Future<void> startVisit(EmployeeVisit visit) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final location = await _ref
          .read(locationServiceProvider)
          .currentLocation();
      final security = _ref
          .read(securityServiceProvider)
          .evaluateLocationIntegrity(
            previous: _lastLocation,
            current: location,
          );
      _lastLocation = location;
      if (!security.isTrusted) throw Exception(security.reasons.join('\n'));
      final distance = _distanceToVisit(visit, location);
      if (distance != null && distance > visit.allowedRadiusMeters) {
        throw Exception(
          'Geo-fence validation failed: ${distance.toStringAsFixed(0)} meters away.',
        );
      }
      final device = await _ref.read(deviceStatusServiceProvider).snapshot();
      final updated = await _ref
          .read(visitRepositoryProvider)
          .startVisit(
            visit.id,
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: location.accuracy,
            batteryPercent: device.batteryPercent,
            networkType: device.internetStatus,
            fakeGpsDetected: location.isMocked,
          );
      _replace(updated.copyWith(distanceMeters: distance));
      state = state.copyWith(
        loading: false,
        message: 'Visit started for ${updated.clientName}.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> saveNotes(String visitId, String notes) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final updated = await _ref
          .read(visitRepositoryProvider)
          .saveNotes(visitId, notes);
      _replace(updated);
      state = state.copyWith(loading: false, message: 'Visit notes saved.');
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> capturePhoto(
    EmployeeVisit visit,
    String category, {
    BuildContext? context,
  }) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final location = await _ref
          .read(locationServiceProvider)
          .currentLocation();
      final captured = await _ref
          .read(cameraServiceProvider)
          .captureWatermarkedImage(
            employeeName: 'Employee',
            clientName: visit.clientName,
            latitude: location.latitude,
            longitude: location.longitude,
            // ignore: use_build_context_synchronously
            context: context,
          );
      final updated = await _ref
          .read(visitRepositoryProvider)
          .uploadPhoto(
            visitId: visit.id,
            file: File(captured.localPath),
            category: category,
            latitude: location.latitude,
            longitude: location.longitude,
          );
      _replace(updated);
      state = state.copyWith(
        loading: false,
        message: '$category photo uploaded.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> submitFieldVisit({
    required FieldVisitDraft draft,
    required BuildContext context,
    bool capturePhoto = true,
  }) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      if (draft.clientName.trim().isEmpty) {
        throw Exception('Client name is required.');
      }
      if (draft.notes.trim().isEmpty) {
        throw Exception('Visit notes are required.');
      }
      if (!capturePhoto) {
        throw Exception('Visit proof photo is required.');
      }
      final location = await _ref
          .read(locationServiceProvider)
          .currentLocation();
      final security = _ref
          .read(securityServiceProvider)
          .evaluateLocationIntegrity(
            previous: _lastLocation,
            current: location,
          );
      _lastLocation = location;
      if (!security.isTrusted) throw Exception(security.reasons.join('\n'));
      final device = await _ref.read(deviceStatusServiceProvider).snapshot();
      File? photo;
      if (capturePhoto) {
        final captured = await _ref
            .read(cameraServiceProvider)
            .captureWatermarkedImage(
              employeeName: 'Employee',
              clientName: draft.clientName,
              latitude: location.latitude,
              longitude: location.longitude,
              // ignore: use_build_context_synchronously
              context: context,
            );
        photo = File(captured.localPath);
      }
      final created = await _ref
          .read(visitRepositoryProvider)
          .submitFieldVisit(
            draft: draft,
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: location.accuracy,
            batteryPercent: device.batteryPercent,
            networkType: device.internetStatus,
            photo: photo,
          );
      state = state.copyWith(
        loading: false,
        visits: [created, ...state.visits],
        message: 'Visit submitted to admin with notes, photo and GPS location.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> uploadSignature(String visitId, Uint8List pngBytes) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final updated = await _ref
          .read(visitRepositoryProvider)
          .uploadSignature(visitId: visitId, pngBytes: pngBytes);
      _replace(updated);
      state = state.copyWith(
        loading: false,
        message: 'Customer signature saved.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> addFollowUp({
    required String visitId,
    required DateTime date,
    required String priority,
    required String notes,
  }) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final updated = await _ref
          .read(visitRepositoryProvider)
          .addFollowUp(
            visitId: visitId,
            date: date,
            priority: priority,
            notes: notes,
          );
      _replace(updated);
      state = state.copyWith(loading: false, message: 'Follow-up created.');
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> endVisit({
    required EmployeeVisit visit,
    required String notes,
    required String outcome,
  }) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      if (outcome.trim().isEmpty) throw Exception('Select a visit outcome.');
      final location = await _ref
          .read(locationServiceProvider)
          .currentLocation();
      final updated = await _ref
          .read(visitRepositoryProvider)
          .endVisit(
            visitId: visit.id,
            notes: notes,
            outcome: outcome,
            latitude: location.latitude,
            longitude: location.longitude,
          );
      _replace(updated);
      state = state.copyWith(
        loading: false,
        message: 'Visit completed for ${updated.clientName}.',
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  void _replace(EmployeeVisit updated) {
    final visits = state.visits
        .map((visit) => visit.id == updated.id ? updated : visit)
        .toList(growable: false);
    state = state.copyWith(visits: visits);
  }

  Future<List<EmployeeVisit>> _withDistance(List<EmployeeVisit> visits) async {
    try {
      final location = await _ref
          .read(locationServiceProvider)
          .currentLocation();
      return visits
          .map(
            (visit) => visit.copyWith(
              distanceMeters: _distanceToVisit(visit, location),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return visits;
    }
  }

  double? _distanceToVisit(EmployeeVisit visit, LocationSnapshot location) {
    if (visit.latitude == null || visit.longitude == null) return null;
    return GeoUtils.distanceMeters(
      location.latitude,
      location.longitude,
      visit.latitude!,
      visit.longitude!,
    );
  }
}
