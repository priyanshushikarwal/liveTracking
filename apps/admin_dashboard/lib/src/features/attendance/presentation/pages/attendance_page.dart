import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client.dart' as sb;
import '../../../../core/widgets/admin_shell.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

class AttendanceRecord {
  final String attendanceId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String location;
  final DateTime attendanceDate;
  final String attendanceTime;
  final String checkOutTime;
  final String status; // present, absent, late, leave, halfday
  final String? employeePhotoUrl;
  final String? selfieUrl;
  final String? checkOutSelfieUrl;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? gpsAccuracy;
  final DateTime? deviceTimestamp;
  final String? storagePath;
  final String? notes;

  AttendanceRecord({
    required this.attendanceId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.location,
    required this.attendanceDate,
    required this.attendanceTime,
    required this.checkOutTime,
    required this.status,
    this.employeePhotoUrl,
    this.selfieUrl,
    this.checkOutSelfieUrl,
    this.latitude,
    this.longitude,
    this.address,
    this.gpsAccuracy,
    this.deviceTimestamp,
    this.storagePath,
    this.notes,
  });

  factory AttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? profile,
  }) {
    final metadata = Map<String, dynamic>.from(
      json['device_metadata'] as Map? ?? const {},
    );
    final checkInAt = _parseDate(json['check_in_at']) ?? DateTime.now();
    final employeeCode =
        _cleanEmployeeCode(profile?['employee_id']) ??
        _cleanEmployeeCode(metadata['employeeId']) ??
        _cleanEmployeeCode(json['employee_code']) ??
        '';
    final employeeName =
        profile?['full_name']?.toString() ??
        metadata['employeeName']?.toString() ??
        json['employee_name']?.toString() ??
        'Unknown';
    final status = _statusFromDatabase(
      json['status']?.toString(),
      checkInAt,
      json['check_out_at'],
    );
    final selfieUrl =
        json['check_in_selfie_url']?.toString() ??
        json['selfie_url']?.toString();
    final checkOutAt = _parseDate(json['check_out_at']);
    final checkOutSelfieUrl = json['check_out_selfie_url']?.toString();

    return AttendanceRecord(
      attendanceId:
          json['attendance_id']?.toString() ?? json['id']?.toString() ?? '',
      employeeId: employeeCode,
      employeeName: employeeName,
      department:
          profile?['department']?.toString() ??
          profile?['department_id']?.toString() ??
          json['department']?.toString() ??
          'Operations',
      location:
          json['location']?.toString() ??
          json['readable_location']?.toString() ??
          json['site_name']?.toString() ??
          'N/A',
      attendanceDate: _parseDate(json['attendance_date']) ?? checkInAt,
      attendanceTime:
          json['attendance_time']?.toString() ??
          DateFormat('hh:mm a').format(checkInAt),
      checkOutTime: checkOutAt == null
          ? 'Not checked out'
          : DateFormat('hh:mm a').format(checkOutAt),
      status: status,
      employeePhotoUrl: _profileImageUrl(profile),
      selfieUrl: selfieUrl,
      checkOutSelfieUrl: checkOutSelfieUrl,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address:
          json['address']?.toString() ??
          json['readable_location']?.toString() ??
          json['site_name']?.toString(),
      gpsAccuracy:
          (json['gps_accuracy'] as num?)?.toDouble() ??
          (metadata['gpsAccuracy'] as num?)?.toDouble(),
      deviceTimestamp: _parseDate(metadata['capturedAt']),
      storagePath: _storagePathFromUrl(selfieUrl),
      notes: json['notes']?.toString(),
    );
  }

  bool get hasSelfie => selfieUrl != null && selfieUrl!.isNotEmpty;
  bool get hasCheckOutSelfie =>
      checkOutSelfieUrl != null && checkOutSelfieUrl!.isNotEmpty;
  bool get hasGps => latitude != null && longitude != null;
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';
  bool get isPresent => status == 'present';
  bool get hasIssues =>
      (gpsAccuracy != null && gpsAccuracy! > 50) ||
      !hasSelfie ||
      !hasGps ||
      isLate;
}

String? _profileImageUrl(Map<String, dynamic>? profile) {
  if (profile == null) return null;
  final meta = Map<String, dynamic>.from(profile['meta'] as Map? ?? const {});
  return meta['photo_url']?.toString() ??
      meta['avatar_url']?.toString() ??
      meta['image_url']?.toString();
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _statusFromDatabase(
  String? value,
  DateTime checkInAt,
  Object? checkOutAt,
) {
  final normalized = (value ?? '').toUpperCase();
  if (normalized.contains('LEAVE')) return 'leave';
  if (normalized.contains('ABSENT')) return 'absent';
  if (normalized.contains('REJECTED')) return 'absent';
  final shiftStart = DateTime(
    checkInAt.year,
    checkInAt.month,
    checkInAt.day,
    9,
    30,
  );
  if (checkInAt.isAfter(shiftStart)) return 'late';
  return 'present';
}

String? _storagePathFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final marker = '/object/public/uploads/';
  final index = url.indexOf(marker);
  if (index == -1) return url;
  return url.substring(index + marker.length);
}

class _AttendanceSummary {
  final int totalEmployees;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final int halfdayCount;
  final double attendanceRate;

  _AttendanceSummary({
    required this.totalEmployees,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.halfdayCount,
  }) : attendanceRate = totalEmployees > 0
           ? ((presentCount + lateCount + halfdayCount) / totalEmployees) * 100
           : 0;

  factory _AttendanceSummary.from(List<AttendanceRecord> records) {
    int present = 0, absent = 0, late = 0, leave = 0, halfday = 0;
    for (final r in records) {
      if (r.isPresent) present++;
      if (r.isAbsent) absent++;
      if (r.isLate) late++;
      if (r.status == 'leave') leave++;
      if (r.status == 'halfday') halfday++;
    }
    return _AttendanceSummary(
      totalEmployees: records.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      leaveCount: leave,
      halfdayCount: halfday,
    );
  }
}

// ============================================================================
// MAIN PAGE
// ============================================================================

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  late Future<List<AttendanceRecord>> _future;
  List<AttendanceRecord> _records = const [];
  String _searchQuery = '';
  String _selectedStatus = 'all';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _future = _loadAttendance();
    _selectedDate = null;
  }

  Future<List<AttendanceRecord>> _loadAttendance() async {
    final SupabaseClient supabase = sb.supabase;
    final attendanceRows =
        await supabase
                .from('attendance')
                .select(
                  'id, organization_id, employee_id, check_in_at, check_out_at, latitude, longitude, check_out_latitude, check_out_longitude, site_name, selfie_url, notes, status, readable_location, check_out_readable_location, gps_accuracy, check_out_gps_accuracy, device_metadata, internet_type, attendance_method, check_in_selfie_url, check_out_selfie_url, created_at',
                )
                .order('check_in_at', ascending: false)
                .limit(500)
            as List<dynamic>? ??
        const [];

    final profileRows =
        await supabase
                .from('profiles')
                .select(
                  'id, full_name, employee_id, department_id, team_id, phone, role, status, meta',
                )
            as List<dynamic>? ??
        const [];
    final profilesById = <String, Map<String, dynamic>>{};
    for (final row in profileRows) {
      final profile = Map<String, dynamic>.from(row as Map);
      profilesById[profile['id']?.toString() ?? ''] = profile;
    }

    final records = attendanceRows
        .map((row) {
          final json = Map<String, dynamic>.from(row as Map);
          final profile = profilesById[json['employee_id']?.toString() ?? ''];
          return AttendanceRecord.fromJson(json, profile: profile);
        })
        .toList(growable: false);

    _records = records;
    return records;
  }

  List<AttendanceRecord> get _filteredRecords {
    return _records.where((record) {
      // Filter by date
      if (_selectedDate != null) {
        final isSameDay =
            record.attendanceDate.year == _selectedDate!.year &&
            record.attendanceDate.month == _selectedDate!.month &&
            record.attendanceDate.day == _selectedDate!.day;
        if (!isSameDay) return false;
      }

      // Filter by status
      if (_selectedStatus != 'all' && record.status != _selectedStatus) {
        return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!record.employeeName.toLowerCase().contains(query) &&
            !record.employeeId.toLowerCase().contains(query) &&
            !record.department.toLowerCase().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _openDialog(String type, AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        return switch (type) {
          'detail' => _AttendanceDetailDialog(record: record),
          'selfie' => _SelfieVerificationDialog(record: record),
          'gps' => _GpsVerificationDialog(record: record),
          'map' => _AttendanceMapDialog(record: record),
          'calendar' => _CalendarViewDialog(record: record),
          'profile' => _EmployeeProfileDialog(record: record),
          'gallery' => _SelfieGalleryDialog(record: record),
          'analytics' => _AttendanceAnalyticsDialog(record: record),
          'late' => _LateAttendanceDialog(records: _filteredRecords),
          'absent' => _AbsentEmployeesDialog(records: _filteredRecords),
          'exceptions' => _ExceptionsDialog(records: _filteredRecords),
          'integrity' => _IntegrityMonitoringDialog(records: _filteredRecords),
          _ => const AlertDialog(
            title: Text('Unknown'),
            content: Text('Unknown dialog type'),
          ),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/attendance',
      title: 'Admin Attendance Center',
      body: FutureBuilder<List<AttendanceRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final summary = _AttendanceSummary.from(_filteredRecords);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _loadAttendance());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Overview Cards (6 metrics)
                _OverviewCards(summary: summary),
                const SizedBox(height: 24),

                // Live Status Section
                _LiveStatusSection(summary: summary),
                const SizedBox(height: 24),

                // Search & Filters
                _SearchAndFilters(
                  searchQuery: _searchQuery,
                  selectedStatus: _selectedStatus,
                  selectedDate: _selectedDate,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onStatusChanged: (v) =>
                      setState(() => _selectedStatus = v ?? 'all'),
                  onDateChanged: (d) => setState(() => _selectedDate = d),
                ),
                const SizedBox(height: 24),

                // Attendance Table
                if (_records.isEmpty)
                  const _AttendanceEmptyState(
                    message:
                        'No attendance rows found in Supabase for this admin account.',
                  )
                else if (_filteredRecords.isEmpty)
                  const _AttendanceEmptyState(
                    message:
                        'Attendance rows exist, but current filters hide them.',
                  )
                else
                  _AttendanceTable(
                    records: _filteredRecords,
                    onViewDetails: (record) => _openDialog('detail', record),
                    onViewSelfie: (record) => _openDialog('selfie', record),
                    onViewGps: (record) => _openDialog('gps', record),
                  ),
                const SizedBox(height: 24),

                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _filteredRecords.isEmpty
                          ? null
                          : () => _openDialog('late', _filteredRecords.first),
                      icon: const Icon(Icons.schedule),
                      label: const Text('Late Attendance'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _filteredRecords.isEmpty
                          ? null
                          : () => _openDialog('absent', _filteredRecords.first),
                      icon: const Icon(Icons.person_off),
                      label: const Text('Absent Employees'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _filteredRecords.isEmpty
                          ? null
                          : () => _openDialog(
                              'exceptions',
                              _filteredRecords.first,
                            ),
                      icon: const Icon(Icons.warning),
                      label: const Text('Exceptions'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _filteredRecords.isEmpty
                          ? null
                          : () => _openDialog(
                              'integrity',
                              _filteredRecords.first,
                            ),
                      icon: const Icon(Icons.verified),
                      label: const Text('Integrity Check'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Export & Reporting
                _ExportReportingSection(
                  records: _filteredRecords,
                  onViewAnalytics: _filteredRecords.isEmpty
                      ? () {}
                      : () => _openDialog('analytics', _filteredRecords.first),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// SCREEN SECTIONS & DIALOGS
// ============================================================================

class _OverviewCards extends StatelessWidget {
  final _AttendanceSummary summary;

  const _OverviewCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _MetricCard(
          title: 'Total Employees',
          value: '${summary.totalEmployees}',
          color: theme.colorScheme.primary,
          icon: Icons.people,
        ),
        _MetricCard(
          title: 'Present',
          value: '${summary.presentCount}',
          color: theme.colorScheme.primary,
          icon: Icons.check_circle,
        ),
        _MetricCard(
          title: 'Absent',
          value: '${summary.absentCount}',
          color: theme.colorScheme.error,
          icon: Icons.cancel,
        ),
        _MetricCard(
          title: 'Late',
          value: '${summary.lateCount}',
          color: theme.colorScheme.secondary,
          icon: Icons.schedule,
        ),
        _MetricCard(
          title: 'Leave',
          value: '${summary.leaveCount}',
          color: theme.colorScheme.secondary,
          icon: Icons.event_busy,
        ),
        _MetricCard(
          title: 'Attendance Rate',
          value: '${summary.attendanceRate.toStringAsFixed(1)}%',
          color: theme.colorScheme.primary,
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(icon, color: color, size: 28),
            Text(
              value,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStatusSection extends StatelessWidget {
  final _AttendanceSummary summary;

  const _LiveStatusSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.live_tv,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE STATUS',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusChip(
                  label: 'Present Today',
                  count: summary.presentCount,
                  color: Theme.of(context).colorScheme.primary,
                ),
                _StatusChip(
                  label: 'Absent Today',
                  count: summary.absentCount,
                  color: Theme.of(context).colorScheme.error,
                ),
                _StatusChip(
                  label: 'Late Check-in',
                  count: summary.lateCount,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                _StatusChip(
                  label: 'On Leave',
                  count: summary.leaveCount,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Text(
        '$count',
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      label: Text(label.toUpperCase()),
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(color: color),
      labelStyle: theme.textTheme.labelSmall,
    );
  }
}

class _AttendanceEmptyState extends StatelessWidget {
  const _AttendanceEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  final String searchQuery;
  final String selectedStatus;
  final DateTime? selectedDate;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<DateTime?> onDateChanged;

  const _SearchAndFilters({
    required this.searchQuery,
    required this.selectedStatus,
    required this.selectedDate,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search & Filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, ID, or department...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(
                        value: 'present',
                        child: Text('Present'),
                      ),
                      DropdownMenuItem(value: 'absent', child: Text('Absent')),
                      DropdownMenuItem(value: 'late', child: Text('Late')),
                      DropdownMenuItem(value: 'leave', child: Text('Leave')),
                    ],
                    onChanged: onStatusChanged,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) onDateChanged(picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        selectedDate != null
                            ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                            : 'All dates',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Show all dates',
                  onPressed: selectedDate == null
                      ? null
                      : () => onDateChanged(null),
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  final List<AttendanceRecord> records;
  final Function(AttendanceRecord) onViewDetails;
  final Function(AttendanceRecord) onViewSelfie;
  final Function(AttendanceRecord) onViewGps;

  const _AttendanceTable({
    required this.records,
    required this.onViewDetails,
    required this.onViewSelfie,
    required this.onViewGps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Photo')),
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Employee ID')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Check-in')),
            DataColumn(label: Text('Check-out')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Selfie Preview')),
            DataColumn(label: Text('GPS')),
            DataColumn(label: Text('Actions')),
          ],
          rows: records.map((record) {
            return DataRow(
              cells: [
                DataCell(_EmployeeAvatar(record: record)),
                DataCell(Text(record.employeeName)),
                DataCell(Text(_employeeIdLabel(record.employeeId))),
                DataCell(Text(record.department)),
                DataCell(
                  Text(DateFormat('dd MMM yyyy').format(record.attendanceDate)),
                ),
                DataCell(Text(record.location)),
                DataCell(Text(record.attendanceTime)),
                DataCell(Text(record.checkOutTime)),
                DataCell(_StatusBadge(status: record.status)),
                DataCell(_SelfiePreview(record: record, onTap: onViewSelfie)),
                DataCell(
                  Tooltip(
                    message: record.hasGps ? 'GPS verified' : 'Missing GPS',
                    child: Icon(
                      record.hasGps ? Icons.location_on : Icons.location_off,
                      color: record.hasGps
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 18),
                        tooltip: 'View Details',
                        onPressed: () => onViewDetails(record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, size: 18),
                        tooltip: 'View Selfie',
                        onPressed: () => onViewSelfie(record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map, size: 18),
                        tooltip: 'View Location',
                        onPressed: () => onViewGps(record),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'absent' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final photoUrl = record.employeePhotoUrl ?? record.selfieUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (_isRenderableImageUrl(photoUrl)) {
        return CircleAvatar(backgroundImage: NetworkImage(photoUrl));
      }
    }
    final initial = record.employeeName.isEmpty
        ? '?'
        : record.employeeName.substring(0, 1).toUpperCase();
    return CircleAvatar(child: Text(initial));
  }
}

class _SelfiePreview extends StatelessWidget {
  const _SelfiePreview({required this.record, required this.onTap});

  final AttendanceRecord record;
  final void Function(AttendanceRecord) onTap;

  @override
  Widget build(BuildContext context) {
    if (!record.hasSelfie) {
      return Tooltip(
        message: 'Missing selfie',
        child: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
      );
    }
    if (!_isRenderableImageUrl(record.selfieUrl!)) {
      return Tooltip(
        message: 'Selfie was not uploaded to Supabase Storage',
        child: Icon(
          Icons.cloud_off,
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    return InkWell(
      onTap: () => onTap(record),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          record.selfieUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.secondary,
            );
          },
        ),
      ),
    );
  }
}

bool _isRenderableImageUrl(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}

class _ExportReportingSection extends StatelessWidget {
  final List<AttendanceRecord> records;
  final VoidCallback onViewAnalytics;

  const _ExportReportingSection({
    required this.records,
    required this.onViewAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export & Reporting',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exporting to Excel...')),
                    );
                  },
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export Excel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating PDF report...')),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
                ElevatedButton.icon(
                  onPressed: onViewAnalytics,
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Analytics'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOG SCREENS (All 12 Detail Views)
// ============================================================================

class _AttendanceDetailDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _AttendanceDetailDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Attendance Details - ${record.employeeName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow('Employee ID', _employeeIdLabel(record.employeeId)),
            _DetailRow('Department', record.department),
            _DetailRow('Location', record.location),
            _DetailRow(
              'Date',
              DateFormat('MMM dd, yyyy').format(record.attendanceDate),
            ),
            _DetailRow('Check-in Time', record.attendanceTime),
            _DetailRow('Check-out Time', record.checkOutTime),
            _DetailRow('Status', record.status.toUpperCase()),
            _DetailRow(
              'Device Timestamp',
              record.deviceTimestamp == null
                  ? 'N/A'
                  : DateFormat(
                      'dd MMM yyyy, hh:mm:ss a',
                    ).format(record.deviceTimestamp!),
            ),
            if (record.hasGps) ...[
              _DetailRow(
                'Latitude',
                record.latitude?.toStringAsFixed(4) ?? 'N/A',
              ),
              _DetailRow(
                'Longitude',
                record.longitude?.toStringAsFixed(4) ?? 'N/A',
              ),
              _DetailRow(
                'Accuracy',
                '${record.gpsAccuracy?.toStringAsFixed(1) ?? "N/A"} m',
              ),
            ],
            if (record.address != null) _DetailRow('Address', record.address!),
            if (record.storagePath != null)
              _DetailRow('Storage Path', record.storagePath!),
            if (record.selfieUrl != null)
              _DetailRow('Check-in Selfie', record.selfieUrl!),
            if (record.checkOutSelfieUrl != null)
              _DetailRow('Check-out Selfie', record.checkOutSelfieUrl!),
            if (record.notes != null) _DetailRow('Notes', record.notes!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SelfieVerificationDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _SelfieVerificationDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selfie Verification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.hasSelfie && _isRenderableImageUrl(record.selfieUrl!))
            Container(
              width: 300,
              height: 300,
              color: Colors.grey[800],
              child: InteractiveViewer(
                child: Image.network(
                  record.selfieUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 100,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              width: 300,
              height: 300,
              color: Colors.grey[800],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.no_photography,
                      size: 100,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    const Text('No Supabase Selfie URL Available'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed:
                    record.hasSelfie && _isRenderableImageUrl(record.selfieUrl!)
                    ? () => showDialog(
                        context: context,
                        builder: (dialogContext) => Dialog.fullscreen(
                          child: Stack(
                            children: [
                              Center(
                                child: InteractiveViewer(
                                  child: Image.network(record.selfieUrl!),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: IconButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Full View'),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check),
                label: const Text('Verify'),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _GpsVerificationDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _GpsVerificationDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GPS Verification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 300,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  if (record.hasGps)
                    Text(
                      '${record.latitude?.toStringAsFixed(4)}, ${record.longitude?.toStringAsFixed(4)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  else
                    const Text('No GPS Data'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (record.hasGps) ...[
            Text(
              'Accuracy: ${record.gpsAccuracy?.toStringAsFixed(1) ?? "N/A"} m',
              style: const TextStyle(fontSize: 12),
            ),
            if (record.address != null) Text('Address: ${record.address}'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => _AttendanceMapDialog(record: record),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('View On Map'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AttendanceMapDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _AttendanceMapDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location Map'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: record.hasGps
            ? FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(record.latitude!, record.longitude!),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.dooninfra.admin_dashboard',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(record.latitude!, record.longitude!),
                        width: 180,
                        height: 72,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              color: Colors.black87,
                              child: Text(
                                '${record.employeeName} • ${record.attendanceTime}',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.location_pin,
                              color: Theme.of(context).colorScheme.primary,
                              size: 36,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(
                    Icons.location_off,
                    size: 100,
                    color: Colors.grey,
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _CalendarViewDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _CalendarViewDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly Attendance Calendar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Calendar for ${DateFormat('MMMM yyyy').format(record.attendanceDate)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(31, (i) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: i % 5 == 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Center(child: Text('${i + 1}')),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _EmployeeProfileDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _EmployeeProfileDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Employee Profile - ${record.employeeName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 50, child: Text(record.employeeName[0])),
            const SizedBox(height: 16),
            _DetailRow('Name', record.employeeName),
            _DetailRow('Employee ID', record.employeeId),
            _DetailRow('Department', record.department),
            _DetailRow('Location', record.location),
            const SizedBox(height: 16),
            Text(
              'Attendance Statistics',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _DetailRow('Present Days', '20'),
            _DetailRow('Absent Days', '2'),
            _DetailRow('Late Days', '3'),
            _DetailRow('Attendance Rate', '88.5%'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SelfieGalleryDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _SelfieGalleryDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Daily Selfie Gallery'),
      content: SizedBox(
        width: 400,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: List.generate(9, (i) {
            return Container(
              color: Colors.grey[800],
              child: const Center(child: Icon(Icons.image, color: Colors.grey)),
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AttendanceAnalyticsDialog extends StatelessWidget {
  final AttendanceRecord record;

  const _AttendanceAnalyticsDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Attendance Analytics'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnalyticsCard(
              title: 'Weekly Trend',
              value: '92%',
              trend: '↑ +5%',
              trendColor: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _AnalyticsCard(
              title: 'Monthly Average',
              value: '88.5%',
              trend: '↓ -2%',
              trendColor: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            _AnalyticsCard(
              title: 'Punctuality Score',
              value: '94%',
              trend: '↑ +8%',
              trendColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final Color trendColor;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  trend,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LateAttendanceDialog extends StatelessWidget {
  final List<AttendanceRecord> records;

  const _LateAttendanceDialog({required this.records});

  @override
  Widget build(BuildContext context) {
    final lateRecords = records.where((r) => r.isLate).toList();
    return AlertDialog(
      title: const Text('Late Attendance Report'),
      content: SizedBox(
        width: 500,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: lateRecords.length,
          itemBuilder: (context, i) {
            final r = lateRecords[i];
            return ListTile(
              title: Text(r.employeeName),
              subtitle: Text('${r.department} - ${r.attendanceTime}'),
              trailing: Icon(
                Icons.schedule,
                color: Theme.of(context).colorScheme.secondary,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _AbsentEmployeesDialog extends StatelessWidget {
  final List<AttendanceRecord> records;

  const _AbsentEmployeesDialog({required this.records});

  @override
  Widget build(BuildContext context) {
    final absentRecords = records.where((r) => r.isAbsent).toList();
    return AlertDialog(
      title: const Text('Absent Employees'),
      content: SizedBox(
        width: 500,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: absentRecords.length,
          itemBuilder: (context, i) {
            final r = absentRecords[i];
            return ListTile(
              title: Text(r.employeeName),
              subtitle: Text(r.department),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, size: 18),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.mail, size: 18),
                    onPressed: () {},
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ExceptionsDialog extends StatelessWidget {
  final List<AttendanceRecord> records;

  const _ExceptionsDialog({required this.records});

  @override
  Widget build(BuildContext context) {
    final exceptionRecords = records.where((r) => r.hasIssues).toList();
    return AlertDialog(
      title: const Text('Exceptions & Issues'),
      content: SizedBox(
        width: 500,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: exceptionRecords.length,
          itemBuilder: (context, i) {
            final r = exceptionRecords[i];
            final issues = <String>[];
            if (!r.hasSelfie) issues.add('Missing Selfie');
            if (!r.hasGps) issues.add('Missing GPS');
            if (r.gpsAccuracy != null && r.gpsAccuracy! > 50) {
              issues.add('Low GPS Accuracy');
            }
            if (r.isLate) issues.add('Late Check-in');

            return ListTile(
              title: Text(r.employeeName),
              subtitle: Text(issues.join(', ')),
              trailing: Icon(
                Icons.warning,
                color: Theme.of(context).colorScheme.secondary,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _IntegrityMonitoringDialog extends StatelessWidget {
  final List<AttendanceRecord> records;

  const _IntegrityMonitoringDialog({required this.records});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Integrity Monitoring'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IntegrityCheck(
              title: 'GPS Accuracy Check',
              passed: records
                  .where((r) => r.gpsAccuracy != null && r.gpsAccuracy! <= 50)
                  .length,
              total: records.where((r) => r.hasGps).length,
              issues: records
                  .where((r) => r.gpsAccuracy != null && r.gpsAccuracy! > 50)
                  .map((r) => r.employeeName)
                  .toList(),
            ),
            const SizedBox(height: 16),
            _IntegrityCheck(
              title: 'Selfie Verification',
              passed: records.where((r) => r.hasSelfie).length,
              total: records.length,
              issues: records
                  .where((r) => !r.hasSelfie)
                  .map((r) => r.employeeName)
                  .toList(),
            ),
            const SizedBox(height: 16),
            _IntegrityCheck(
              title: 'GPS Location Recorded',
              passed: records.where((r) => r.hasGps).length,
              total: records.length,
              issues: records
                  .where((r) => !r.hasGps)
                  .map((r) => r.employeeName)
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _IntegrityCheck extends StatelessWidget {
  final String title;
  final int passed;
  final int total;
  final List<String> issues;

  const _IntegrityCheck({
    required this.title,
    required this.passed,
    required this.total,
    required this.issues,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0
        ? (passed / total * 100).toStringAsFixed(1)
        : '0';
    final color = passed == total
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$passed/$total ($percentage%)',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Issues: ${issues.join(", ")}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

String? _cleanEmployeeCode(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (uuidPattern.hasMatch(text)) return null;
  return text;
}

String _employeeIdLabel(String employeeId) {
  if (employeeId.isEmpty) return 'Employee ID pending';
  return employeeId;
}
