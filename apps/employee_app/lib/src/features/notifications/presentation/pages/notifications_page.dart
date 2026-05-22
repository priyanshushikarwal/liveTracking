import 'package:flutter/material.dart';

import '../../../../core/widgets/app_shell.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'Attendance reminder',
        'Check in when you reach the assigned field site.',
        Icons.how_to_reg_outlined,
      ),
      (
        'Visit reminder',
        'Metro Retail LLP visit is scheduled for today.',
        Icons.storefront_outlined,
      ),
      (
        'Admin announcement',
        'Keep location and battery optimization permissions enabled.',
        Icons.campaign_outlined,
      ),
    ];

    return AppShell(
      title: 'Notifications',
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.$3),
            title: Text(item.$1),
            subtitle: Text(item.$2),
            trailing: const Icon(Icons.chevron_right),
          );
        },
      ),
    );
  }
}
