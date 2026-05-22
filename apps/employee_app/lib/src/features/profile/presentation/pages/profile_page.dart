import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_shell.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Profile',
      body: ListView(
        children: [
          const ListTile(
            title: Text('Employee'),
            subtitle: Text('Field Executive • Operations'),
          ),
          const ListTile(
            title: Text('Employee ID'),
            subtitle: Text('Unavailable'),
          ),
          const ListTile(
            title: Text('Registered Phone'),
            subtitle: Text('Unavailable'),
          ),
          const ListTile(
            title: Text('Device Binding'),
            subtitle: Text(
              'Bound to corporate-issued device with secure storage',
            ),
          ),
          ListTile(
            title: const Text('Session Security'),
            subtitle: Text(
              AppConfig.useDemoMode
                  ? 'Demo mode enabled with secure local session restore'
                  : 'JWT session secured with device-bound token storage',
            ),
          ),
        ],
      ),
    );
  }
}
