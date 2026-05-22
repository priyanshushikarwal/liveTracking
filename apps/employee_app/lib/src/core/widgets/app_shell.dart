import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _pathToIndex(location);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: Theme.of(context).colorScheme.outline),
        ),
        actions: [
          ...actions,
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case '/history':
                case '/analytics':
                case '/notifications':
                case '/live-status':
                case '/profile':
                case '/camera':
                case '/settings':
                  context.push(value);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: '/history', child: Text('HISTORY')),
              PopupMenuItem(value: '/analytics', child: Text('ANALYTICS')),
              PopupMenuItem(
                value: '/notifications',
                child: Text('NOTIFICATIONS'),
              ),
              PopupMenuItem(value: '/live-status', child: Text('LIVE STATUS')),
              PopupMenuItem(value: '/profile', child: Text('PROFILE')),
              PopupMenuItem(value: '/camera', child: Text('CAMERA')),
              PopupMenuItem(value: '/settings', child: Text('SETTINGS')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: body,
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => context.go(_indexToPath(index)),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: 'DASHBOARD',
            ),
            NavigationDestination(
              icon: Icon(Icons.how_to_reg_outlined),
              label: 'ATTENDANCE',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              label: 'VISITS',
            ),
            NavigationDestination(
              icon: Icon(Icons.my_location_outlined),
              label: 'TRACKING',
            ),
          ],
        ),
      ),
    );
  }

  int _pathToIndex(String path) {
    if (path.startsWith('/attendance')) {
      return 1;
    }
    if (path.startsWith('/visits')) {
      return 2;
    }
    if (path.startsWith('/tracking')) {
      return 3;
    }
    return 0;
  }

  String _indexToPath(int index) {
    switch (index) {
      case 1:
        return '/attendance';
      case 2:
        return '/visits';
      case 3:
        return '/tracking';
      case 0:
      default:
        return '/dashboard';
    }
  }
}
