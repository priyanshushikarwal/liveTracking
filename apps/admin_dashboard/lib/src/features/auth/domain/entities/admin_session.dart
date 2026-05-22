class AdminSession {
  const AdminSession({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.name,
    required this.organizationId,
  });

  final String accessToken;
  final String refreshToken;
  final String role;
  final String name;
  final String organizationId;
}
