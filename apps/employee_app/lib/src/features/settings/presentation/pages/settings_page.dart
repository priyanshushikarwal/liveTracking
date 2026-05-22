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
            title: const Text('Background Tracking'),
            subtitle: const Text(
              'Battery-optimized tracking with offline sync queue',
            ),
            value: trackingState.trackingEnabled,
            onChanged: (_) =>
                ref.read(trackingViewModelProvider.notifier).toggleTracking(),
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
            title: const Text('Offline Queue'),
            subtitle: Text(
              '${trackingState.pendingSyncItems} item(s) waiting to sync',
            ),
            trailing: OutlinedButton(
              onPressed: () =>
                  ref.read(trackingViewModelProvider.notifier).syncNow(),
              child: const Text('SYNC'),
            ),
          ),
        ],
      ),
    );
  }
}
