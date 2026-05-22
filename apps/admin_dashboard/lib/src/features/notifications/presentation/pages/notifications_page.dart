import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_shell.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/notifications',
      title: 'Notifications',
      body: ListView(
        children: const [
          ListTile(
            title: Text('Fake GPS Alert'),
            subtitle: Text('EMP-2048 flagged for suspicious location jump'),
          ),
          ListTile(
            title: Text('Offline Employee Alert'),
            subtitle: Text('EMP-3011 has been offline for 18 minutes'),
          ),
        ],
      ),
    );
  }
}
