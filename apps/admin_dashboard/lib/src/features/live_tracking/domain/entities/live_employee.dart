class LiveEmployee {
  const LiveEmployee({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.department,
    required this.designation,
    required this.teamName,
    required this.branchLabel,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.bearing,
    required this.accuracy,
    required this.speed,
    required this.distanceTodayMeters,
    required this.battery,
    required this.internetStatus,
    required this.gpsStatus,
    required this.lastSyncAt,
    required this.lastActiveAt,
    required this.trackingStatus,
    required this.isOnline,
  });

  final String id;
  final String employeeCode;
  final String name;
  final String department;
  final String designation;
  final String teamName;
  final String branchLabel;
  final String status;
  final double latitude;
  final double longitude;
  final double bearing;
  final double accuracy;
  final double speed;
  final double distanceTodayMeters;
  final int battery;
  final String internetStatus;
  final String gpsStatus;
  final DateTime lastSyncAt;
  final DateTime lastActiveAt;
  final String trackingStatus;
  final bool isOnline;

  LiveEmployee copyWith({
    String? id,
    String? employeeCode,
    String? name,
    String? department,
    String? designation,
    String? teamName,
    String? branchLabel,
    String? status,
    double? latitude,
    double? longitude,
    double? bearing,
    double? accuracy,
    double? speed,
    double? distanceTodayMeters,
    int? battery,
    String? internetStatus,
    String? gpsStatus,
    DateTime? lastSyncAt,
    DateTime? lastActiveAt,
    String? trackingStatus,
    bool? isOnline,
  }) {
    return LiveEmployee(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      name: name ?? this.name,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      teamName: teamName ?? this.teamName,
      branchLabel: branchLabel ?? this.branchLabel,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bearing: bearing ?? this.bearing,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      distanceTodayMeters: distanceTodayMeters ?? this.distanceTodayMeters,
      battery: battery ?? this.battery,
      internetStatus: internetStatus ?? this.internetStatus,
      gpsStatus: gpsStatus ?? this.gpsStatus,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      trackingStatus: trackingStatus ?? this.trackingStatus,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
