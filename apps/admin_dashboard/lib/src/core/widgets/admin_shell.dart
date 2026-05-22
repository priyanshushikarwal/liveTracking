import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.currentLocation,
    required this.title,
    required this.body,
  });

  final String currentLocation;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, IconData icon, String route})>[
      (label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/dashboard'),
      (
        label: 'Live Tracking',
        icon: Icons.location_searching_outlined,
        route: '/tracking',
      ),
      (
        label: 'Attendance',
        icon: Icons.fact_check_outlined,
        route: '/attendance',
      ),
      (label: 'Visits', icon: Icons.storefront_outlined, route: '/visits'),
      (label: 'Employees', icon: Icons.people_outline, route: '/employees'),
      (label: 'Analytics', icon: Icons.insights_outlined, route: '/analytics'),
      (label: 'Reports', icon: Icons.file_download_outlined, route: '/reports'),
      (
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        route: '/notifications',
      ),
      (label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
    ];
    final selectedIndex = items.indexWhere(
      (item) => currentLocation.startsWith(item.route),
    );

    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            child: NavigationRail(
              extended: true,
              minExtendedWidth: 248,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'LIVETRACK',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              groupAlignment: -0.82,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (index) => context.go(items[index].route),
              destinations: items
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label.toUpperCase()),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.toUpperCase(),
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          tooltip: 'Search',
                          icon: const Icon(Icons.search),
                        ),
                        IconButton(
                          onPressed: () {},
                          tooltip: 'Fullscreen',
                          icon: const Icon(Icons.fullscreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 24),
                    Expanded(child: body),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
