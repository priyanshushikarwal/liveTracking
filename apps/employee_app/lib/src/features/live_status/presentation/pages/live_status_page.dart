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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              tracking.trackingEnabled
                  ? Icons.radar_outlined
                  : Icons.location_searching_outlined,
            ),
            title: const Text('Duty tracking'),
            subtitle: Text(
              tracking.trackingEnabled
                  ? 'Broadcasting live field status'
                  : 'Starting automatic tracking',
            ),
            trailing: Chip(
              label: Text(
                tracking.permissionDenied
                    ? 'PERMISSION NEEDED'
                    : tracking.trackingEnabled
                    ? 'ACTIVE'
                    : 'STARTING',
              ),
            ),
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
        ],
      ),
    );
  }
}
