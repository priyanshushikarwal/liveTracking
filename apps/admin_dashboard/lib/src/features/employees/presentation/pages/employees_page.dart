import 'package:flutter/material.dart';

import '../../../../core/widgets/admin_shell.dart';
import '../../data/services/employee_service.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late Future<List<Map<String, dynamic>>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = EmployeeService().listEmployees();
  }

  void _refresh() {
    setState(() {
      _employeesFuture = EmployeeService().listEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentLocation: '/employees',
      title: 'Employees',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EMPLOYEE DIRECTORY',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                onPressed: _showCreateEmployeeDialog,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('CREATE EMPLOYEE'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _employeesFuture,
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
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    final meta = Map<String, dynamic>.from(
                      employee['meta'] as Map? ?? const {},
                    );
                    final name =
                        employee['full_name']?.toString() ?? 'Employee';
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
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateEmployeeDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(text: _generatePassword());
    final phoneController = TextEditingController();
    final departmentController = TextEditingController();
    final teamController = TextEditingController();
    final branchController = TextEditingController();
    final shiftController = TextEditingController();

    Map<String, dynamic>? result;
    var loading = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            if (loading) return;
            if (nameController.text.trim().isEmpty ||
                emailController.text.trim().isEmpty ||
                passwordController.text.isEmpty) {
              setState(() => error = 'Name, email and password are required');
              return;
            }
            if (passwordController.text.length < 6) {
              setState(() => error = 'Password must be at least 6 characters');
              return;
            }
            setState(() {
              loading = true;
              error = null;
            });
            try {
              result = await EmployeeService().createEmployee(
                fullName: nameController.text.trim(),
                email: emailController.text.trim(),
                password: passwordController.text,
                phone: phoneController.text.trim(),
                department: departmentController.text.trim(),
                team: teamController.text.trim(),
                branch: branchController.text.trim(),
                shift: shiftController.text.trim(),
              );
              setState(() {});
            } catch (e) {
              error = e.toString().replaceFirst('Exception: ', '');
            }
            setState(() => loading = false);
          }

          final createdProfile = result?['profile'] as Map<String, dynamic>?;
          final createdUser = result?['user'] as Map<String, dynamic>?;
          final password = result?['password']?.toString() ?? '';

          return AlertDialog(
            title: Text(
              result == null ? 'CREATE EMPLOYEE' : 'EMPLOYEE CREATED',
            ),
            content: SizedBox(
              width: 520,
              child: result == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password for employee app',
                            suffixIcon: IconButton(
                              tooltip: 'Generate password',
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                setState(() {
                                  passwordController.text = _generatePassword();
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: departmentController,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: teamController,
                          decoration: const InputDecoration(labelText: 'Team'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: branchController,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: shiftController,
                          decoration: const InputDecoration(labelText: 'Shift'),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CredentialLine(
                          label: 'Employee ID',
                          value:
                              createdProfile?['employee_id']?.toString() ??
                              '--',
                        ),
                        _CredentialLine(
                          label: 'Email',
                          value: createdUser?['email']?.toString() ?? '--',
                        ),
                        _CredentialLine(
                          label: 'Password',
                          value: password.isEmpty ? '--' : password,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Share these credentials with the employee to login to the employee app.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: loading
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                child: const Text('CLOSE'),
              ),
              if (result == null)
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: Text(loading ? 'CREATING...' : 'CREATE'),
                ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    departmentController.dispose();
    teamController.dispose();
    branchController.dispose();
    shiftController.dispose();

    if (result != null && mounted) {
      _refresh();
    }
  }

  String _generatePassword() {
    final suffix = DateTime.now().millisecondsSinceEpoch
        .remainder(9000)
        .toString()
        .padLeft(4, '0');
    return 'Emp@$suffix';
  }
}

class _CredentialLine extends StatelessWidget {
  const _CredentialLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '--' : value)),
        ],
      ),
    );
  }
}
