class EmployeeProfile {
  const EmployeeProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.designation,
    required this.department,
    this.organizationId = '',
  });

  final String id;
  final String name;
  final String phone;
  final String designation;
  final String department;
  final String organizationId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'designation': designation,
      'department': department,
      'organizationId': organizationId,
    };
  }

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      department: json['department'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
    );
  }
}
