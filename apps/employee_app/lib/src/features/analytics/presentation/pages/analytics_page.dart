import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/stat_card.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceViewModelProvider);
    final visits = ref.watch(visitViewModelProvider);
    final tracking = ref.watch(trackingViewModelProvider);
    final completedVisits = visits.visits
        .where((visit) => visit.status == 'Completed')
        .length;

    return AppShell(
      title: 'Analytics',
      body: ListView(
        children: [
          Text(
            'PRODUCTIVITY SCORE',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              StatCard(
                label: 'Score',
                value: '${70 + completedVisits * 5}',
                subtitle: 'Weighted field productivity',
              ),
              StatCard(
                label: 'Visits',
                value: '$completedVisits',
                subtitle: 'Completed and verified',
              ),
              StatCard(
                label: 'Attendance',
                value: '${attendance.records.length}',
                subtitle: 'Recorded sessions',
              ),
              StatCard(
                label: 'Sync Queue',
                value: '${tracking.pendingSyncItems}',
                subtitle: 'Offline items',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Stats'.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(value: 0.82),
                  const SizedBox(height: 12),
                  const Text(
                    'Work hours, visit completion, tracking continuity and attendance reliability are combined for the live score.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
