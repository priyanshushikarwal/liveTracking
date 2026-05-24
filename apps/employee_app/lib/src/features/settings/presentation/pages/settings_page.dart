import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final trackingState = ref.watch(trackingViewModelProvider);
    return AppShell(
      title: 'Settings',
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text(
              'Admin alerts, reminders and policy announcements',
            ),
            value: notificationsEnabled,
            onChanged: (value) => setState(() => notificationsEnabled = value),
          ),
          ListTile(
            title: const Text('Tracking Status'),
            subtitle: Text(
              trackingState.trackingEnabled
                  ? 'Tracking Active'
                  : 'Starting automatic tracking',
            ),
            trailing: Chip(
              label: Text('${trackingState.pendingSyncItems} queued'),
            ),
          ),
        ],
      ),
    );
  }
}
