import 'package:flutter/material.dart';

import '../../../../core/supabase/supabase_client.dart' as sb;
import '../../../../core/widgets/admin_shell.dart';
import '../../../../core/widgets/metric_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadDashboardSummary();
  }

  void _refresh() {
    setState(() {
      _summaryFuture = _loadDashboardSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/dashboard',
      title: 'Dashboard',
      body: _DashboardContent(future: _summaryFuture, onRefresh: _refresh),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.future, required this.onRefresh});

  final Future<_DashboardSummary> future;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardSummary>(
      future: future,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? _DashboardSummary.empty();
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error?.toString().replaceFirst(
          'Exception: ',
          '',
        );

        return ListView(
          children: [
            if (error != null) ...[
              _DashboardError(message: error, onRefresh: onRefresh),
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1200 ? 4 : 2;
                final cards = [
                  MetricCard(
                    label: 'Active Employees',
                    value: loading ? '--' : '${summary.activeEmployees}',
                    subtitle: 'Live workforce count',
                  ),
                  MetricCard(
                    label: 'Visits Today',
                    value: loading ? '--' : '${summary.visitsCompletedToday}',
                    subtitle: 'Completed and verified',
                  ),
                  MetricCard(
                    label: 'Attendance %',
                    value: loading
                        ? '--%'
                        : '${summary.attendancePercent.toStringAsFixed(0)}%',
                    subtitle: 'Checked in today',
                  ),
                  MetricCard(
                    label: 'Distance Travelled',
                    value: loading
                        ? '-- km'
                        : '${(summary.distanceMeters / 1000).toStringAsFixed(1)} km',
                    subtitle: 'Across all field teams',
                  ),
                ];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  itemBuilder: (_, index) => cards[index],
                );
              },
            ),
            const SizedBox(height: 20),
            _ExecutiveSnapshot(summary: summary, loading: loading),
          ],
        );
      },
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRefresh});

  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutiveSnapshot extends StatelessWidget {
  const _ExecutiveSnapshot({required this.summary, required this.loading});

  final _DashboardSummary summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final topTeamTitle = loading
        ? 'Loading'
        : summary.topTeamName == null
        ? 'No completed visits today'
        : summary.topTeamName!;
    final topTeamSubtitle = loading
        ? 'Checking live dashboard data'
        : summary.topTeamName == null
        ? 'Completed visit data will appear once employees submit visits'
        : '${summary.topTeamVisits} visits completed today';

    final alertSubtitle = loading
        ? 'Checking latest location sync'
        : summary.staleEmployees == 0
        ? 'All active employees have recent location sync'
        : '${summary.staleEmployees} employees have not synced location in the last 15 minutes';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXECUTIVE SNAPSHOT',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Top performing team'),
              subtitle: Text('$topTeamTitle • $topTeamSubtitle'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Critical alert'),
              subtitle: Text(alertSubtitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSummary {
  const _DashboardSummary({
    required this.activeEmployees,
    required this.visitsCompletedToday,
    required this.attendancePercent,
    required this.distanceMeters,
    required this.staleEmployees,
    required this.topTeamName,
    required this.topTeamVisits,
  });

  final int activeEmployees;
  final int visitsCompletedToday;
  final double attendancePercent;
  final double distanceMeters;
  final int staleEmployees;
  final String? topTeamName;
  final int topTeamVisits;

  factory _DashboardSummary.empty() {
    return const _DashboardSummary(
      activeEmployees: 0,
      visitsCompletedToday: 0,
      attendancePercent: 0,
      distanceMeters: 0,
      staleEmployees: 0,
      topTeamName: null,
      topTeamVisits: 0,
    );
  }
}

Future<_DashboardSummary> _loadDashboardSummary() async {
  final supabase = sb.supabase;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrowStart = todayStart.add(const Duration(days: 1));
  final staleCutoff = now.subtract(const Duration(minutes: 15));

  final profileRows =
      await supabase
              .from('profiles')
              .select('id, full_name, employee_id, role, status, meta')
              .ilike('role', 'employee')
          as List<dynamic>? ??
      const [];
  final profiles = profileRows
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
  final activeProfiles = profiles
      .where((profile) {
        return _isActive(profile['status']);
      })
      .toList(growable: false);
  final activeProfileIds = activeProfiles
      .map((profile) => profile['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  final attendanceRows =
      await supabase
              .from('attendance')
              .select('employee_id, check_in_at, distance_travelled_meters')
              .gte('check_in_at', todayStart.toUtc().toIso8601String())
              .lt('check_in_at', tomorrowStart.toUtc().toIso8601String())
          as List<dynamic>? ??
      const [];
  final presentEmployeeIds = attendanceRows
      .map((row) => (row as Map)['employee_id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
  final attendanceDistance = attendanceRows.fold<double>(0, (sum, row) {
    final value = (row as Map)['distance_travelled_meters'];
    return sum + _num(value);
  });

  final visitRows =
      await supabase
              .from('visits')
              .select('employee_id, status, scheduled_at')
              .gte('scheduled_at', todayStart.toUtc().toIso8601String())
              .lt('scheduled_at', tomorrowStart.toUtc().toIso8601String())
          as List<dynamic>? ??
      const [];
  final completedVisits = visitRows
      .map((row) => Map<String, dynamic>.from(row as Map))
      .where((visit) => _isCompletedVisit(visit['status']))
      .toList(growable: false);

  final locationRows =
      await supabase
              .from('live_locations')
              .select('employee_id, recorded_at')
              .order('recorded_at', ascending: false)
              .limit(1000)
          as List<dynamic>? ??
      const [];
  final latestLocationByEmployee = <String, DateTime>{};
  for (final row in locationRows) {
    final map = Map<String, dynamic>.from(row as Map);
    final employeeId = map['employee_id']?.toString() ?? '';
    final recordedAt = DateTime.tryParse(map['recorded_at']?.toString() ?? '');
    if (employeeId.isEmpty || recordedAt == null) continue;
    latestLocationByEmployee.putIfAbsent(employeeId, () => recordedAt);
  }
  final staleEmployees = activeProfileIds.where((employeeId) {
    final recordedAt = latestLocationByEmployee[employeeId];
    return recordedAt == null || recordedAt.isBefore(staleCutoff);
  }).length;

  final historyDistance = await _loadLocationHistoryDistance(
    todayStart,
    tomorrowStart,
  );
  final topTeam = _topTeam(completedVisits, profiles);

  return _DashboardSummary(
    activeEmployees: activeProfiles.length,
    visitsCompletedToday: completedVisits.length,
    attendancePercent: activeProfiles.isEmpty
        ? 0
        : (presentEmployeeIds.length / activeProfiles.length) * 100,
    distanceMeters: historyDistance > 0 ? historyDistance : attendanceDistance,
    staleEmployees: staleEmployees,
    topTeamName: topTeam.name,
    topTeamVisits: topTeam.visits,
  );
}

Future<double> _loadLocationHistoryDistance(
  DateTime todayStart,
  DateTime tomorrowStart,
) async {
  try {
    final rows =
        await sb.supabase
                .from('location_history')
                .select('distance_meters, recorded_at')
                .gte('recorded_at', todayStart.toUtc().toIso8601String())
                .lt('recorded_at', tomorrowStart.toUtc().toIso8601String())
            as List<dynamic>? ??
        const [];
    return rows.fold<double>(0, (sum, row) {
      return sum + _num((row as Map)['distance_meters']);
    });
  } catch (_) {
    return 0;
  }
}

_TopTeam _topTeam(
  List<Map<String, dynamic>> completedVisits,
  List<Map<String, dynamic>> profiles,
) {
  if (completedVisits.isEmpty) return const _TopTeam(null, 0);
  final profilesById = {
    for (final profile in profiles) profile['id']?.toString() ?? '': profile,
  };
  final counts = <String, int>{};
  for (final visit in completedVisits) {
    final profile = profilesById[visit['employee_id']?.toString() ?? ''];
    final meta = Map<String, dynamic>.from(profile?['meta'] as Map? ?? {});
    final team = _cleanText(meta['team']) ?? 'Unassigned team';
    counts[team] = (counts[team] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return _TopTeam(entries.first.key, entries.first.value);
}

class _TopTeam {
  const _TopTeam(this.name, this.visits);

  final String? name;
  final int visits;
}

bool _isActive(Object? value) {
  return (value?.toString() ?? '').trim().toLowerCase() == 'active';
}

bool _isCompletedVisit(Object? value) {
  final status = (value?.toString() ?? '').trim().toLowerCase();
  return status == 'completed' || status == 'verified';
}

String? _cleanText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
