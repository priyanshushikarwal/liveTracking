import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client.dart' as sb;

class EmployeeService {
  EmployeeService();

  Future<List<Map<String, dynamic>>> listEmployees() async {
    final SupabaseClient supabase = sb.supabase;
    final rows =
        await supabase
                .from('profiles')
                .select(
                  'id, full_name, employee_id, department_id, role, status, meta',
                )
                .ilike('role', 'employee')
                .order('full_name')
            as List<dynamic>? ??
        const [];

    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createEmployee({
    required String fullName,
    required String email,
    String? phone,
    String? department,
    String? team,
    String? branch,
    String? shift,
    String role = 'EMPLOYEE',
    String? branchId,
    String? departmentId,
    String? teamId,
  }) async {
    final SupabaseClient supabase = sb.supabase;
    final payload = {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'branch_id': branchId,
      'department_id': departmentId,
      'team_id': teamId,
      'department': department,
      'team': team,
      'branch': branch,
      'shift': shift,
    };

    final resp = await supabase.functions.invoke(
      'create_employee',
      body: jsonEncode(payload),
    );
    final Map<String, dynamic> data = resp.data as Map<String, dynamic>;
    return data;
  }
}
