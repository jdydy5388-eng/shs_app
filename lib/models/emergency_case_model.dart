enum TriageLevel { red, orange, yellow, green, blue }
enum EmergencyStatus { waiting, in_treatment, stabilized, transferred, discharged }

class EmergencyCaseModel {
  final String id;
  final String? patientId;
  final String? patientName;
  final TriageLevel triageLevel;
  final EmergencyStatus status;
  final Map<String, dynamic>? vitalSigns;
  final String? symptoms;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmergencyCaseModel({
    required this.id,
    this.patientId,
    this.patientName,
    required this.triageLevel,
    required this.status,
    this.vitalSigns,
    this.symptoms,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory EmergencyCaseModel.fromMap(Map<String, dynamic> map, String id) {
    final triageStr = (map['triageLevel'] ?? map['triage_level'] ?? 'green') as String;
    final statusStr = (map['status'] ?? 'waiting') as String;
    final triage = TriageLevel.values.firstWhere(
      (e) => e.toString().split('.').last == triageStr,
      orElse: () => TriageLevel.green,
    );
    final status = EmergencyStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => EmergencyStatus.waiting,
    );
    final vital = map['vitalSigns'] as Map<String, dynamic>? ??
        (map['vital_signs'] is Map ? Map<String, dynamic>.from(map['vital_signs'] as Map) : null);

    return EmergencyCaseModel(
      id: id,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String?,
      patientName: map['patientName'] as String? ?? map['patient_name'] as String?,
      triageLevel: triage,
      status: status,
      vitalSigns: vital,
      symptoms: map['symptoms'] as String?,
      notes: map['notes'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'triageLevel': triageLevel.toString().split('.').last,
        'status': status.toString().split('.').last,
        'vitalSigns': vitalSigns,
        'symptoms': symptoms,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };
}

class EmergencyEventModel {
  final String id;
  final String caseId;
  final String eventType;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  EmergencyEventModel({
    required this.id,
    required this.caseId,
    required this.eventType,
    this.details,
    required this.createdAt,
  });

  static DateTime _parse(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return DateTime.now();
  }

  factory EmergencyEventModel.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyEventModel(
      id: id,
      caseId: map['caseId'] as String? ?? map['case_id'] as String? ?? '',
      eventType: map['eventType'] as String? ?? map['event_type'] as String? ?? '',
      details: map['details'] != null ? Map<String, dynamic>.from(map['details'] as Map) : null,
      createdAt: _parse(map['createdAt'] ?? map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'caseId': caseId,
        'eventType': eventType,
        'details': details,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}


