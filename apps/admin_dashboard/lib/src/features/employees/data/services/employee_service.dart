import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client.dart' as sb;

class EmployeeService {
  EmployeeService();

  Future<Map<String, dynamic>> createEmployee({
    required String fullName,
    required String email,
    String? phone,
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
    };

    final resp = await supabase.functions.invoke(
      'create_employee',
      body: jsonEncode(payload),
    );
    final Map<String, dynamic> data = resp.data as Map<String, dynamic>;
    return data;
  }
}
