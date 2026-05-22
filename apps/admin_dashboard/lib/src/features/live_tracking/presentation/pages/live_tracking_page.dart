import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/admin_shell.dart';
import '../../domain/entities/live_employee.dart';
import '../viewmodels/live_tracking_view_model.dart';
import '../widgets/live_tracking_map.dart';

class LiveTrackingPage extends ConsumerStatefulWidget {
  const LiveTrackingPage({super.key});

  @override
  ConsumerState<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends ConsumerState<LiveTrackingPage> {
  bool _fullscreen = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveTrackingViewModelProvider);
    final notifier = ref.read(liveTrackingViewModelProvider.notifier);
    final summary = _TrackingSummary.from(state.employees);
    final selected = state.selectedEmployee;
    final mapEmployees = state.filteredEmployees
        .where(
          (employee) =>
              employee.isOnline &&
              (employee.latitude != 0 || employee.longitude != 0),
        )
        .toList(growable: false);

    return AdminShell(
      currentLocation: '/tracking',
      title: 'Live Tracking',
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _OverviewGrid(summary: summary),
                const SizedBox(height: 24),
                _TrackingControls(
                  state: state,
                  notifier: notifier,
                  onViewDailyRoute: () {
                    final employee = state.selectedEmployee;
                    if (employee != null) {
                      notifier.loadPlayback(employee.id);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 700,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: LiveTrackingMap(
                          employees: mapEmployees,
                          routeVisitPins: state.routeVisitPins,
                          selectedEmployee: selected,
                          routeTrails: state.routeTrails,
                          playback: state.playback,
                          playbackCursor: state.playbackCursor,
                          stopMarkers: notifier.stopMarkers(),
                          statusColor: notifier.statusColor,
                          onEmployeeTap: notifier.selectEmployee,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: _EmployeeTrackingPanel(
                          employee: selected,
                          state: state,
                          notifier: notifier,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _LiveEmployeeList(
                  employees: state.filteredEmployees,
                  selectedId: state.selectedEmployeeId,
                  onSelect: notifier.selectEmployee,
                  onViewDailyRoute: () {
                    final employee = state.selectedEmployee;
                    if (employee != null) {
                      notifier.loadPlayback(employee.id);
                    }
                  },
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorPanel(message: state.error!),
                ],
              ],
            ),
          ),
          if (_fullscreen)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.96),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'LIVE TRACKING FULLSCREEN',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () =>
                                  setState(() => _fullscreen = false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: LiveTrackingMap(
                            employees: mapEmployees,
                            routeVisitPins: state.routeVisitPins,
                            selectedEmployee: selected,
                            routeTrails: state.routeTrails,
                            playback: state.playback,
                            playbackCursor: state.playbackCursor,
                            stopMarkers: notifier.stopMarkers(),
                            statusColor: notifier.statusColor,
                            onEmployeeTap: notifier.selectEmployee,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackingSummary {
  const _TrackingSummary({
    required this.total,
    required this.online,
    required this.offline,
    required this.moving,
    required this.stationary,
    required this.checkedIn,
    required this.checkedOut,
  });

  final int total;
  final int online;
  final int offline;
  final int moving;
  final int stationary;
  final int checkedIn;
  final int checkedOut;

  factory _TrackingSummary.from(List<LiveEmployee> employees) {
    var online = 0;
    var moving = 0;
    var stationary = 0;
    var checkedIn = 0;
    for (final employee in employees) {
      final status = employee.trackingStatus.toLowerCase();
      if (employee.isOnline) online++;
      if (status.contains('moving') || status.contains('travel')) {
        moving++;
      } else if (employee.isOnline) {
        stationary++;
      }
      if (employee.latitude != 0 || employee.longitude != 0) checkedIn++;
    }
    return _TrackingSummary(
      total: employees.length,
      online: online,
      offline: employees.length - online,
      moving: moving,
      stationary: stationary,
      checkedIn: checkedIn,
      checkedOut: employees.length - checkedIn,
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.summary});

  final _TrackingSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(label: 'Total Employees', value: summary.total),
      _MetricCard(label: 'Online', value: summary.online),
      _MetricCard(label: 'Offline', value: summary.offline),
      _MetricCard(label: 'Moving', value: summary.moving),
      _MetricCard(label: 'Stationary', value: summary.stationary),
      _MetricCard(label: 'Checked In', value: summary.checkedIn),
      _MetricCard(label: 'Checked Out', value: summary.checkedOut),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1280
            ? 7
            : constraints.maxWidth > 900
            ? 4
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (_, index) => cards[index],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text('$value', style: theme.textTheme.headlineLarge),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state, required this.notifier});

  final LiveTrackingState state;
  final LiveTrackingViewModel notifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(context),
      child: TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search employee, ID, department',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: notifier.updateSearch,
      ),
    );
  }
}

class _TrackingControls extends StatelessWidget {
  const _TrackingControls({
    required this.state,
    required this.notifier,
    required this.onViewDailyRoute,
  });

  final LiveTrackingState state;
  final LiveTrackingViewModel notifier;
  final VoidCallback onViewDailyRoute;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final search = SizedBox(
          width: wide ? 360 : double.infinity,
          child: _FilterBar(state: state, notifier: notifier),
        );
        final selector = SizedBox(
          width: wide ? 420 : double.infinity,
          child: _EmployeeSelector(state: state, notifier: notifier),
        );
        final routeButton = SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: state.selectedEmployee == null ? null : onViewDailyRoute,
            icon: const Icon(Icons.route_outlined),
            label: const Text('VIEW DAILY ROUTE'),
          ),
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 12),
              selector,
              const SizedBox(height: 12),
              routeButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            search,
            const SizedBox(width: 14),
            selector,
            const SizedBox(width: 14),
            routeButton,
          ],
        );
      },
    );
  }
}

class _EmployeeSelector extends StatelessWidget {
  const _EmployeeSelector({required this.state, required this.notifier});

  final LiveTrackingState state;
  final LiveTrackingViewModel notifier;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedEmployee;
    final selectedId = selected == null
        ? null
        : state.employees.any((employee) => employee.id == selected.id)
        ? selected.id
        : null;

    return Container(
      decoration: _panelDecoration(context),
      child: DropdownButtonFormField<String>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.person_search_outlined),
          labelText: 'Select employee',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: state.employees
            .map(
              (employee) => DropdownMenuItem<String>(
                value: employee.id,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: employee.isOnline
                            ? const Color(0xFF54F1A6)
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${employee.name.toUpperCase()} • ${employee.employeeCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          if (value != null) notifier.selectEmployee(value);
        },
      ),
    );
  }
}

class _EmployeeTrackingPanel extends StatelessWidget {
  const _EmployeeTrackingPanel({
    required this.employee,
    required this.state,
    required this.notifier,
  });

  final LiveEmployee? employee;
  final LiveTrackingState state;
  final LiveTrackingViewModel notifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeStart = state.playback.isEmpty
        ? '--'
        : _timeLabel(state.playback.first.recordedAt);
    final routeEnd = state.playback.isEmpty
        ? '--'
        : _timeLabel(state.playback.last.recordedAt);
    return Container(
      decoration: _panelDecoration(context),
      child: employee == null
          ? Center(
              child: Text(
                'SELECT AN EMPLOYEE',
                style: theme.textTheme.labelLarge,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        onPressed: () {},
                      ),
                      Text(
                        'EMPLOYEE TRACKING',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.surface,
                        backgroundImage: NetworkImage(
                          'https://i.pravatar.cc/150?u=${employee!.id}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee!.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              '${employee!.employeeCode} • ${employee!.department}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _DetailRow(
                        'Status',
                        employee!.isOnline ? 'Online' : 'Offline',
                        isStatus: true,
                        online: employee!.isOnline,
                      ),
                      _DetailRow(
                        'Location',
                        '${employee!.latitude.toStringAsFixed(5)}, ${employee!.longitude.toStringAsFixed(5)}',
                      ),
                      _DetailRow(
                        'Speed',
                        '${_speedKmh(employee!).toStringAsFixed(1)} km/h',
                      ),
                      _DetailRow(
                        'Today Distance',
                        '${_distanceKm(state.playback).toStringAsFixed(2)} km',
                      ),
                      _DetailRow('Battery', '${employee!.battery}%'),
                      _DetailRow('Network', employee!.internetStatus),
                      const SizedBox(height: 24),
                      Text('DAILY ROUTE', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: state.routeDate,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  notifier.updateSelectedDate(picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(_dateLabel(state.routeDate)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: state.playbackPlaying
                                ? 'Pause route playback'
                                : 'Play route playback',
                            onPressed: state.playback.isEmpty
                                ? null
                                : notifier.togglePlayback,
                            icon: Icon(
                              state.playbackPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.colorScheme.outline,
                          thumbColor: theme.colorScheme.primary,
                          overlayColor: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                        ),
                        child: Slider(
                          value: state.playback.isEmpty
                              ? 0
                              : state.playbackIndex.toDouble().clamp(
                                  0,
                                  (state.playback.length - 1).toDouble(),
                                ),
                          max: state.playback.isEmpty
                              ? 1
                              : (state.playback.length - 1).toDouble(),
                          onChanged: state.playback.isEmpty
                              ? null
                              : notifier.seekPlayback,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(routeStart, style: theme.textTheme.bodySmall),
                          Flexible(
                            child: Text(
                              '${state.playback.length} GPS/visit points • ${state.routeVisitPins.length} visits',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Text(routeEnd, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton(
                    onPressed: state.playbackLoading
                        ? null
                        : () => notifier.loadPlayback(employee!.id),
                    child: Text(
                      state.playbackLoading
                          ? 'LOADING ROUTE...'
                          : 'VIEW DAILY ROUTE',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
    this.label,
    this.value, {
    this.isStatus = false,
    this.online = false,
  });

  final String label;
  final String value;
  final bool isStatus;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isStatus && !online
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveEmployeeList extends StatelessWidget {
  const _LiveEmployeeList({
    required this.employees,
    required this.selectedId,
    required this.onSelect,
    required this.onViewDailyRoute,
  });

  final List<LiveEmployee> employees;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onViewDailyRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LIVE EMPLOYEE LIST', style: theme.textTheme.titleLarge),
                OutlinedButton(
                  onPressed: selectedId == null ? null : onViewDailyRoute,
                  child: const Text('VIEW DAILY ROUTE'),
                ),
              ],
            ),
          ),
          DataTable(
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('PHOTO')),
              DataColumn(label: Text('EMPLOYEE')),
              DataColumn(label: Text('EMPLOYEE ID')),
              DataColumn(label: Text('CURRENT LOCATION')),
              DataColumn(label: Text('STATUS')),
            ],
            rows: employees.map((employee) {
              final selected = employee.id == selectedId;
              return DataRow(
                selected: selected,
                onSelectChanged: (_) => onSelect(employee.id),
                cells: [
                  DataCell(
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.surface,
                      backgroundImage: NetworkImage(
                        'https://i.pravatar.cc/150?u=${employee.id}',
                      ),
                    ),
                  ),
                  DataCell(Text(employee.name)),
                  DataCell(Text(employee.employeeCode)),
                  DataCell(
                    Text(
                      '${employee.latitude.toStringAsFixed(5)}, ${employee.longitude.toStringAsFixed(5)}',
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: employee.isOnline
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(employee.isOnline ? 'ONLINE' : 'STATIONARY'),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(context).copyWith(
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Text(message),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Theme.of(context).colorScheme.outline),
  );
}

double _speedKmh(LiveEmployee employee) {
  return employee.speed * 3.6;
}

double _distanceKm(List<PlaybackPoint> points) {
  if (points.length < 2) return 0;
  final distance = const Distance();
  var meters = 0.0;
  for (var index = 1; index < points.length; index++) {
    meters += distance.as(
      LengthUnit.Meter,
      points[index - 1].latLng,
      points[index].latLng,
    );
  }
  return meters / 1000;
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _timeLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
