import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/app_shell.dart';

class TrackingPage extends ConsumerWidget {
  const TrackingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingViewModelProvider);
    final visits = ref.watch(visitViewModelProvider).visits;
    final theme = Theme.of(context);
    final lastLocation = state.lastLocation;
    final distanceKm = _distanceKm(state.route);
    final activeTime = _activeTimeLabel(state.route);
    final visitsToday = visits.where((visit) {
      return visit.isCompleted &&
          _sameLocalDay(visit.startTime, DateTime.now());
    }).length;

    return AppShell(
      title: 'Tracking',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Text(
            'Today\'s Tracking Summary',
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 720;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: wide ? 1.15 : 1.05,
                children: [
                  _GlassStatCard(
                    title: 'Distance Today',
                    value: '${distanceKm.toStringAsFixed(1)} km',
                    hint: lastLocation == null
                        ? 'Waiting for GPS'
                        : 'Updated ${_timeLabel(lastLocation.timestamp)}',
                  ),
                  _GlassStatCard(
                    title: 'Active Time',
                    value: activeTime,
                    hint: '${state.route.length} route points today',
                  ),
                  _GlassStatCard(
                    title: 'Visits',
                    value: '$visitsToday',
                    hint: 'Completed today',
                  ),
                  _GlassStatCard(
                    title: 'Status',
                    value: state.permissionDenied
                        ? 'Permission Needed'
                        : state.trackingEnabled
                        ? 'Tracking Active'
                        : 'Starting',
                    hint: state.internetStatus,
                  ),
                ],
              );
            },
          ),
          if (state.permissionDenied) ...[
            const SizedBox(height: 16),
            Text(
              'Location permission is required for duty tracking.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 10),
            Text(
              state.error!.replaceFirst('Exception: ', ''),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  static double _distanceKm(List<LocationSnapshot> route) {
    if (route.length < 2) return 0;
    const distance = Distance();
    var meters = 0.0;
    for (var index = 1; index < route.length; index++) {
      final previous = route[index - 1];
      final current = route[index];
      meters += distance.as(
        LengthUnit.Meter,
        LatLng(previous.latitude, previous.longitude),
        LatLng(current.latitude, current.longitude),
      );
    }
    return meters / 1000;
  }

  static String _activeTimeLabel(List<LocationSnapshot> route) {
    if (route.length < 2) return '0m';
    final start = route.first.timestamp;
    final end = route.last.timestamp;
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  static bool _sameLocalDay(DateTime left, DateTime right) {
    final a = left.toLocal();
    final b = right.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({
    required this.title,
    required this.value,
    required this.hint,
  });

  final String title;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(hint, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
