import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceViewModelProvider).records;
    final visits = ref.watch(visitViewModelProvider).visits;

    return AppShell(
      title: 'History',
      body: ListView(
        children: [
          Text(
            'ATTENDANCE HISTORY',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          ...attendance.map(
            (record) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(record.siteName),
              subtitle: Text('${record.status} • ${record.checkInTime}'),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'VISIT HISTORY',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          ...visits.map(
            (visit) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(visit.clientName),
              subtitle: Text(
                '${visit.status} • ${visit.notes.isEmpty ? visit.siteAddress : visit.notes}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
