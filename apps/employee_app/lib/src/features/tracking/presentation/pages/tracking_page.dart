import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';
import '../viewmodels/tracking_view_model.dart';
import '../widgets/tracking_map.dart';

class TrackingPage extends ConsumerWidget {
  const TrackingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackingViewModelProvider);
    final notifier = ref.read(trackingViewModelProvider.notifier);
    final theme = Theme.of(context);
    final lastLocation = state.lastLocation;

    return AppShell(
      title: 'Tracking',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatusChip(
                      icon: state.trackingEnabled
                          ? Icons.radar
                          : Icons.pause_circle_outline,
                      label: state.trackingEnabled ? 'Tracking live' : 'Paused',
                      color: state.trackingEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                    ),
                    _StatusChip(
                      icon:
                          state.connectionStatus ==
                              TrackingConnectionStatus.connected
                          ? Icons.wifi_tethering
                          : Icons.wifi_off,
                      label: switch (state.connectionStatus) {
                        TrackingConnectionStatus.connected => 'Socket live',
                        TrackingConnectionStatus.connecting =>
                          'Socket connecting',
                        TrackingConnectionStatus.disconnected =>
                          'Socket offline',
                      },
                      color: switch (state.connectionStatus) {
                        TrackingConnectionStatus.connected =>
                          theme.colorScheme.primary,
                        TrackingConnectionStatus.connecting =>
                          theme.colorScheme.secondary,
                        TrackingConnectionStatus.disconnected =>
                          theme.colorScheme.error,
                      },
                    ),
                    _StatusChip(
                      icon: state.gpsEnabled ? Icons.gps_fixed : Icons.gps_off,
                      label: state.gpsEnabled ? 'GPS ready' : 'GPS unavailable',
                      color: state.gpsEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                    _StatusChip(
                      icon: Icons.battery_6_bar,
                      label: 'Battery ${state.batteryPercent}%',
                      color: theme.colorScheme.primary,
                    ),
                    _StatusChip(
                      icon: Icons.network_check,
                      label: state.internetStatus,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 440,
                  child: TrackingMap(
                    routePoints: state.route
                        .map((point) => LatLng(point.latitude, point.longitude))
                        .toList(growable: false),
                    serverRoutePoints: state.serverRoute
                        .map((point) => LatLng(point.latitude, point.longitude))
                        .toList(growable: false),
                    currentPoint: lastLocation == null
                        ? null
                        : LatLng(lastLocation.latitude, lastLocation.longitude),
                    accuracyMeters: lastLocation?.accuracy ?? 0,
                    followEmployee: state.followEmployee,
                    onToggleFollow: notifier.toggleFollowEmployee,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _GlassStatCard(
                        title: 'Latest fix',
                        value: lastLocation == null
                            ? 'Waiting for GPS'
                            : '${lastLocation.latitude.toStringAsFixed(5)}, ${lastLocation.longitude.toStringAsFixed(5)}',
                        hint: lastLocation == null
                            ? 'Grant location access to start live plotting'
                            : 'Accuracy ${lastLocation.accuracy.toStringAsFixed(0)} m',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _GlassStatCard(
                        title: 'Route trail',
                        value: '${state.route.length} points',
                        hint: state.serverAcknowledgedAt == null
                            ? 'Awaiting server acknowledgment'
                            : 'Server synced ${_timeLabel(state.serverAcknowledgedAt!)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 420,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('BACKGROUND LIVE TRACKING'),
                        subtitle: const Text(
                          'Auto-publish movement updates with queue fallback',
                        ),
                        value: state.trackingEnabled,
                        onChanged: state.loading
                            ? null
                            : (_) => notifier.toggleTracking(),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: state.loading
                          ? null
                          : notifier.captureLocationPing,
                      icon: const Icon(Icons.my_location),
                      label: const Text('PING NOW'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: state.loading ? null : notifier.syncNow,
                      icon: const Icon(Icons.sync),
                      label: const Text('SYNC'),
                    ),
                  ],
                ),
                if (state.lastSyncSummary != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    state.lastSyncSummary!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (state.permissionDenied) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Location permission is blocked. Enable it in app settings to resume live tracking.',
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
          ),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.58)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
