import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/widgets/admin_shell.dart';
import '../../../../core/widgets/metric_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShell(
      currentLocation: '/dashboard',
      title: 'Dashboard',
      body: _DashboardContent(),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dio = ref.watch(dioProvider);
    return ListView(
      children: [
        FutureBuilder(
          future: dio.get('/reports/summary'),
          builder: (context, snapshot) {
            final data = Map<String, dynamic>.from(
              snapshot.data?.data as Map? ?? const {},
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 1200 ? 4 : 2;
                final cards = [
                  MetricCard(
                    label: 'Active Employees',
                    value: '${data['activeEmployees'] ?? '--'}',
                    subtitle: 'Live workforce count',
                  ),
                  MetricCard(
                    label: 'Visits Today',
                    value: '${data['visitsCompleted'] ?? '--'}',
                    subtitle: 'Completed and verified',
                  ),
                  MetricCard(
                    label: 'Attendance %',
                    value: '${data['attendancePercent'] ?? '--'}%',
                    subtitle: 'Checked in today',
                  ),
                  MetricCard(
                    label: 'Distance Travelled',
                    value:
                        '${(((data['distanceMeters'] as num?) ?? 0) / 1000).toStringAsFixed(1)} km',
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
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXECUTIVE SNAPSHOT',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Top performing team'),
                  subtitle: Text(
                    'Retail Expansion West • 312 visits completed today',
                  ),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Critical alert'),
                  subtitle: Text(
                    '11 employees have not synced location in the last 15 minutes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
