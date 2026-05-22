import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_shell.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/reports',
      title: 'Reports',
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXPORT CENTER',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  ElevatedButton(onPressed: () {}, child: const Text('PDF')),
                  ElevatedButton(onPressed: () {}, child: const Text('EXCEL')),
                  ElevatedButton(onPressed: () {}, child: const Text('CSV')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
