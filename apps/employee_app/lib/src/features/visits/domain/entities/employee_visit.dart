class EmployeeVisit {
  const EmployeeVisit({
    required this.id,
    required this.clientName,
    required this.siteAddress,
    required this.scheduledAt,
    required this.status,
    this.clientId,
    this.organizationId,
    this.contactPerson = 'Primary contact',
    this.phone = '',
    this.email = '',
    this.visitType = 'Client Visit',
    this.priority = 'Medium',
    this.clientType = 'Enterprise',
    this.clientCategory = 'General',
    this.assignedBy = 'Admin',
    this.objective = 'Client meeting',
    this.latitude,
    this.longitude,
    this.allowedRadiusMeters = 120,
    this.distanceMeters,
    this.startedAt,
    this.endTime,
    this.notes = '',
    this.outcome,
    this.productivityScore = 0,
    this.photos = const [],
    this.documents = const [],
    this.audioNotes = const [],
    this.followUps = const [],
    this.activities = const [],
    this.previousVisits = const [],
  });

  final String id;
  final String? clientId;
  final String? organizationId;
  final String clientName;
  final String contactPerson;
  final String phone;
  final String email;
  final String siteAddress;
  final String visitType;
  final String priority;
  final String clientType;
  final String clientCategory;
  final String assignedBy;
  final String objective;
  final double? latitude;
  final double? longitude;
  final double allowedRadiusMeters;
  final double? distanceMeters;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? endTime;
  final String status;
  final String notes;
  final String? outcome;
  final int productivityScore;
  final List<VisitAttachment> photos;
  final List<VisitAttachment> documents;
  final List<VisitAttachment> audioNotes;
  final List<VisitFollowUp> followUps;
  final List<VisitActivity> activities;
  final List<EmployeeVisit> previousVisits;

  DateTime get startTime => startedAt ?? scheduledAt;

  bool get isActive => status == 'In Progress' && endTime == null;

  bool get isCompleted => status == 'Completed';

  Duration? get duration {
    if (startedAt == null) return null;
    return (endTime ?? DateTime.now()).difference(startedAt!);
  }

  EmployeeVisit copyWith({
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endTime,
    String? status,
    String? notes,
    String? outcome,
    int? productivityScore,
    double? distanceMeters,
    List<VisitAttachment>? photos,
    List<VisitAttachment>? documents,
    List<VisitAttachment>? audioNotes,
    List<VisitFollowUp>? followUps,
    List<VisitActivity>? activities,
    List<EmployeeVisit>? previousVisits,
  }) {
    return EmployeeVisit(
      id: id,
      clientId: clientId,
      organizationId: organizationId,
      clientName: clientName,
      contactPerson: contactPerson,
      phone: phone,
      email: email,
      siteAddress: siteAddress,
      visitType: visitType,
      priority: priority,
      clientType: clientType,
      clientCategory: clientCategory,
      assignedBy: assignedBy,
      objective: objective,
      latitude: latitude,
      longitude: longitude,
      allowedRadiusMeters: allowedRadiusMeters,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      outcome: outcome ?? this.outcome,
      productivityScore: productivityScore ?? this.productivityScore,
      photos: photos ?? this.photos,
      documents: documents ?? this.documents,
      audioNotes: audioNotes ?? this.audioNotes,
      followUps: followUps ?? this.followUps,
      activities: activities ?? this.activities,
      previousVisits: previousVisits ?? this.previousVisits,
    );
  }
}

class VisitAttachment {
  const VisitAttachment({
    required this.id,
    required this.label,
    required this.url,
    required this.createdAt,
    this.category = 'Other',
    this.readableLocation,
  });

  final String id;
  final String label;
  final String category;
  final String url;
  final DateTime createdAt;
  final String? readableLocation;
}

class VisitFollowUp {
  const VisitFollowUp({
    required this.id,
    required this.date,
    required this.priority,
    required this.notes,
    this.completed = false,
  });

  final String id;
  final DateTime date;
  final String priority;
  final String notes;
  final bool completed;
}

class VisitActivity {
  const VisitActivity({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String message;
  final DateTime createdAt;
}

class FieldVisitDraft {
  const FieldVisitDraft({
    required this.clientName,
    required this.notes,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.objective = 'Field visit submitted by employee',
    this.visitType = 'Field Visit',
    this.priority = 'Medium',
    this.outcome = 'Field Visit Submitted',
  });

  final String clientName;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String objective;
  final String visitType;
  final String priority;
  final String outcome;
  final String notes;
}
