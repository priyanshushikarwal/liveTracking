import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/stat_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    final attendanceNotifier = ref.read(attendanceViewModelProvider.notifier);
    final visitNotifier = ref.read(visitViewModelProvider.notifier);
    Future.microtask(() async {
      await attendanceNotifier.loadHistory();
      if (!mounted) return;
      await visitNotifier.loadVisits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceViewModelProvider);
    final visitState = ref.watch(visitViewModelProvider);
    final activeVisitCount = visitState.visits
        .where((visit) => visit.isActive)
        .length;
    final completedVisitCount = visitState.visits
        .where((visit) => visit.status == 'Completed')
        .length;
    final todayAttendance =
        attendanceState.activeRecord?.checkInTime ??
        attendanceState.records.firstOrNull?.checkInTime;
    final cards = [
      StatCard(
        label: 'Today Attendance',
        value: todayAttendance == null
            ? 'Pending'
            : TimeOfDay.fromDateTime(todayAttendance).format(context),
        subtitle:
            attendanceState.activeRecord?.siteName ??
            'Tap attendance to check in',
      ),
      StatCard(
        label: 'Total Visits',
        value: visitState.visits.length.toString().padLeft(2, '0'),
        subtitle: '$activeVisitCount active, $completedVisitCount completed',
      ),
      StatCard(
        label: 'Queue Pending',
        value: ref.watch(trackingViewModelProvider).pendingSyncItems.toString(),
        subtitle: 'Offline sync items waiting to upload',
      ),
      StatCard(
        label: 'Current Status',
        value: attendanceState.activeRecord == null ? 'OFF SITE' : 'ON DUTY',
        subtitle: 'Operations',
      ),
    ];

    return AppShell(
      title: 'Dashboard',
      actions: [
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        children: [
          Text(
            'Welcome, Employee',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'TODAY OVERVIEW',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 900;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: wide ? 1.2 : 1.05,
                ),
                itemBuilder: (context, index) => cards[index],
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Tasks'.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Complete geo-tagged photo audit'),
                    subtitle: Text('Metro Retail LLP • due in 40 minutes'),
                    trailing: Chip(label: Text('HIGH')),
                  ),
                  ...visitState.visits
                      .take(2)
                      .map(
                        (visit) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(visit.clientName),
                          subtitle: Text(
                            '${visit.siteAddress} • ${visit.status}',
                          ),
                          trailing: Chip(
                            label: Text(visit.status.toUpperCase()),
                          ),
                        ),
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
