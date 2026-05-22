import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_shell.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/employees',
      title: 'Employees',
      body: ListView(
        children: const [
          ListTile(
            title: Text('Aarav Mehta'),
            subtitle: Text('Field Sales Executive • North Zone • Device bound'),
          ),
          ListTile(
            title: Text('Sara Khan'),
            subtitle: Text('Merchandising Lead • Retail Ops • Active'),
          ),
        ],
      ),
    );
  }
}
