class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.checkInTime,
    required this.siteName,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.checkOutTime,
    this.readableLocation,
    this.checkOutReadableLocation,
    this.confidenceScore = 0,
    this.riskLevel = 'MEDIUM',
    this.verificationStatus = 'LOW CONFIDENCE',
    this.gpsAccuracy,
    this.internetType,
    this.batteryPercent,
    this.checkInSelfieUrl,
    this.checkOutSelfieUrl,
    this.workDurationMinutes,
    this.distanceTravelledMeters,
    this.totalVisits,
    this.productivityScore,
    this.syncStatus = 'SYNCED',
  });

  final String id;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String siteName;
  final double latitude;
  final double longitude;
  final String status;
  final String? readableLocation;
  final String? checkOutReadableLocation;
  final int confidenceScore;
  final String riskLevel;
  final String verificationStatus;
  final double? gpsAccuracy;
  final String? internetType;
  final int? batteryPercent;
  final String? checkInSelfieUrl;
  final String? checkOutSelfieUrl;
  final int? workDurationMinutes;
  final double? distanceTravelledMeters;
  final int? totalVisits;
  final int? productivityScore;
  final String syncStatus;

  String get displayLocation => readableLocation ?? siteName;

  AttendanceRecord copyWith({
    DateTime? checkOutTime,
    String? status,
    String? syncStatus,
  }) {
    return AttendanceRecord(
      id: id,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      siteName: siteName,
      latitude: latitude,
      longitude: longitude,
      status: status ?? this.status,
      readableLocation: readableLocation,
      checkOutReadableLocation: checkOutReadableLocation,
      confidenceScore: confidenceScore,
      riskLevel: riskLevel,
      verificationStatus: verificationStatus,
      gpsAccuracy: gpsAccuracy,
      internetType: internetType,
      batteryPercent: batteryPercent,
      checkInSelfieUrl: checkInSelfieUrl,
      checkOutSelfieUrl: checkOutSelfieUrl,
      workDurationMinutes: workDurationMinutes,
      distanceTravelledMeters: distanceTravelledMeters,
      totalVisits: totalVisits,
      productivityScore: productivityScore,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
