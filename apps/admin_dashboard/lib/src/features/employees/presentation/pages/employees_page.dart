import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_shell.dart';
import '../../data/services/employee_service.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/employees',
      title: 'Employees',
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: EmployeeService().listEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString().replaceFirst('Exception: ', ''),
              ),
            );
          }

          final employees = snapshot.data ?? const [];
          if (employees.isEmpty) {
            return const Center(child: Text('No employees found'));
          }

          return ListView.separated(
            itemCount: employees.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final employee = employees[index];
              final meta = Map<String, dynamic>.from(
                employee['meta'] as Map? ?? const {},
              );
              final name = employee['full_name']?.toString() ?? 'Employee';
              final employeeCode =
                  employee['employee_id']?.toString().trim() ?? '';
              final department =
                  meta['department']?.toString().trim().isNotEmpty == true
                  ? meta['department'].toString()
                  : employee['department_id']?.toString() ?? 'Operations';
              final status = employee['status']?.toString() ?? 'ACTIVE';
              final photoUrl =
                  meta['photo_url']?.toString() ??
                  meta['avatar_url']?.toString() ??
                  meta['profile_photo']?.toString();

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: photoUrl == null || photoUrl.isEmpty
                      ? null
                      : NetworkImage(photoUrl),
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                      : null,
                ),
                title: Text(name),
                subtitle: Text(
                  '${employeeCode.isEmpty ? 'Employee ID pending' : employeeCode} • $department',
                ),
                trailing: Chip(label: Text(status.toUpperCase())),
              );
            },
          );
        },
      ),
    );
  }
}
