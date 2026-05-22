import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_shell.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/analytics',
      title: 'Analytics',
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRODUCTIVITY ANALYTICS',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Charts for route heatmaps, stop duration analytics, attendance percentage and team performance plug into this area.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
