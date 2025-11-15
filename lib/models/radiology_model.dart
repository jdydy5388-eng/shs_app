enum RadiologyStatus { requested, scheduled, completed, cancelled }

class RadiologyRequestModel {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String modality; // xray/mri/ct/us/other
  final String? bodyPart;
  final RadiologyStatus status;
  final String? notes;
  final DateTime requestedAt;
  final DateTime? scheduledAt;
  final DateTime? completedAt;

  RadiologyRequestModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.modality,
    this.bodyPart,
    required this.status,
    required this.requestedAt,
    this.scheduledAt,
    this.completedAt,
    this.notes,
  });

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory RadiologyRequestModel.fromMap(Map<String, dynamic> map, String id) {
    final statusStr = (map['status'] as String?) ?? 'requested';
    final status = RadiologyStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => RadiologyStatus.requested,
    );
    return RadiologyRequestModel(
      id: id,
      doctorId: map['doctorId'] as String? ?? map['doctor_id'] as String? ?? '',
      patientId: map['patientId'] as String? ?? map['patient_id'] as String? ?? '',
      patientName: map['patientName'] as String? ?? map['patient_name'] as String? ?? '',
      modality: map['modality'] as String? ?? 'xray',
      bodyPart: map['bodyPart'] as String? ?? map['body_part'] as String?,
      status: status,
      requestedAt: _parse(map['requestedAt'] ?? map['requested_at']) ?? DateTime.now(),
      scheduledAt: _parse(map['scheduledAt'] ?? map['scheduled_at']),
      completedAt: _parse(map['completedAt'] ?? map['completed_at']),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'doctorId': doctorId,
        'patientId': patientId,
        'patientName': patientName,
        'modality': modality,
        'bodyPart': bodyPart,
        'status': status.toString().split('.').last,
        'notes': notes,
        'requestedAt': requestedAt.millisecondsSinceEpoch,
        'scheduledAt': scheduledAt?.millisecondsSinceEpoch,
        'completedAt': completedAt?.millisecondsSinceEpoch,
      };
}

class RadiologyReportModel {
  final String id;
  final String requestId;
  final String? findings;
  final String? impression;
  final List<String>? attachments;
  final DateTime createdAt;

  RadiologyReportModel({
    required this.id,
    required this.requestId,
    this.findings,
    this.impression,
    this.attachments,
    required this.createdAt,
  });

  static DateTime _parse(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return DateTime.now();
  }

  factory RadiologyReportModel.fromMap(Map<String, dynamic> map, String id) {
    List<String>? parseList(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => '$e').toList();
      return null;
    }
    return RadiologyReportModel(
      id: id,
      requestId: map['requestId'] as String? ?? map['request_id'] as String? ?? '',
      findings: map['findings'] as String?,
      impression: map['impression'] as String?,
      attachments: parseList(map['attachments']),
      createdAt: _parse(map['createdAt'] ?? map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'requestId': requestId,
        'findings': findings,
        'impression': impression,
        'attachments': attachments,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}


