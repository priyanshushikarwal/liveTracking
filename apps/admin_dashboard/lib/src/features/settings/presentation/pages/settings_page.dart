import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/admin_shell.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return AdminShell(
      currentLocation: '/settings',
      title: 'Settings',
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const ListTile(
            title: Text('Multi-company SaaS'),
            subtitle: Text(
              'Organization, branch and team hierarchy management hooks',
            ),
          ),
          const ListTile(
            title: Text('Role Guards'),
            subtitle: Text('HR, Admin and Super Admin access control'),
          ),
        ],
      ),
    );
  }
}
