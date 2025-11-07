enum LabRequestStatus { pending, inProgress, completed, cancelled }

class LabRequestModel {
  const LabRequestModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.testType,
    required this.status,
    required this.requestedAt,
    this.notes,
    this.resultNotes,
    this.attachments,
    this.completedAt,
  });

  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String testType;
  final LabRequestStatus status;
  final String? notes;
  final String? resultNotes;
  final List<String>? attachments;
  final DateTime requestedAt;
  final DateTime? completedAt;

  LabRequestModel copyWith({
    String? id,
    String? doctorId,
    String? patientId,
    String? patientName,
    String? testType,
    LabRequestStatus? status,
    String? notes,
    String? resultNotes,
    List<String>? attachments,
    DateTime? requestedAt,
    DateTime? completedAt,
  }) {
    return LabRequestModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      testType: testType ?? this.testType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      resultNotes: resultNotes ?? this.resultNotes,
      attachments: attachments ?? this.attachments,
      requestedAt: requestedAt ?? this.requestedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'patient_name': patientName,
      'test_type': testType,
      'status': status.toString().split('.').last,
      'notes': notes,
      'result_notes': resultNotes,
      'attachments': attachments != null ? attachments!.join('|') : null,
      'requested_at': requestedAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory LabRequestModel.fromMap(Map<String, dynamic> map) {
    return LabRequestModel(
      id: map['id'] as String,
      doctorId: map['doctor_id'] as String,
      patientId: map['patient_id'] as String,
      patientName: map['patient_name'] as String,
      testType: map['test_type'] as String,
      status: LabRequestStatus.values.firstWhere(
        (status) => status.toString().split('.').last == map['status'],
        orElse: () => LabRequestStatus.pending,
      ),
      notes: map['notes'] as String?,
      resultNotes: map['result_notes'] as String?,
      attachments: (map['attachments'] as String?)?.split('|').where((e) => e.isNotEmpty).toList(),
      requestedAt:
          DateTime.fromMillisecondsSinceEpoch(map['requested_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
    );
  }
}
