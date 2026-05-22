import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';

class LiveStatusPage extends ConsumerWidget {
  const LiveStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingViewModelProvider);
    final attendance = ref.watch(attendanceViewModelProvider);

    return AppShell(
      title: 'Live Status',
      body: ListView(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Duty tracking'),
            subtitle: Text(
              tracking.trackingEnabled
                  ? 'Broadcasting live field status'
                  : 'Tracking paused',
            ),
            value: tracking.trackingEnabled,
            onChanged: (_) =>
                ref.read(trackingViewModelProvider.notifier).toggleTracking(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.work_history_outlined),
            title: const Text('Attendance'),
            subtitle: Text(
              attendance.activeRecord == null
                  ? 'Off duty'
                  : 'Checked in at ${attendance.activeRecord!.siteName}',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.my_location_outlined),
            title: const Text('Last location'),
            subtitle: Text(
              tracking.lastLocation == null
                  ? 'No ping captured yet'
                  : '${tracking.lastLocation!.latitude.toStringAsFixed(5)}, ${tracking.lastLocation!.longitude.toStringAsFixed(5)}',
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => ref
                .read(trackingViewModelProvider.notifier)
                .captureLocationPing(),
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('SEND LIVE PING'),
          ),
        ],
      ),
    );
  }
}
