class DoctorAppointment {
  const DoctorAppointment({
    required this.id,
    required this.doctorId,
    required this.date,
    required this.status,
    required this.createdAt,
    this.patientId,
    this.patientName,
    this.type,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String doctorId;
  final String? patientId;
  final String? patientName;
  final DateTime date;
  final AppointmentStatus status;
  final String? type;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DoctorAppointment copyWith({
    String? id,
    String? doctorId,
    String? patientId,
    String? patientName,
    DateTime? date,
    AppointmentStatus? status,
    String? type,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoctorAppointment(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      date: date ?? this.date,
      status: status ?? this.status,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'patient_id': patientId,
      'patient_name': patientName,
      'date': date.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      'type': type,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory DoctorAppointment.fromMap(Map<String, dynamic> map) {
    // معالجة التاريخ - قد يكون int أو DateTime أو null
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return DoctorAppointment(
      id: (map['id'] ?? map['Id'] ?? '').toString(),
      doctorId: (map['doctor_id'] ?? map['doctorId'] ?? '').toString(),
      patientId: map['patient_id'] ?? map['patientId'] as String?,
      patientName: map['patient_name'] ?? map['patientName'] as String?,
      date: parseDateTime(map['date'] ?? map['Date']),
      status: AppointmentStatus.values.firstWhere(
        (status) {
          final statusValue = map['status'] ?? map['Status'] ?? '';
          return status.toString().split('.').last == statusValue.toString();
        },
        orElse: () => AppointmentStatus.scheduled,
      ),
      type: map['type'] ?? map['Type'] as String?,
      notes: map['notes'] ?? map['Notes'] as String?,
      createdAt: parseDateTime(map['created_at'] ?? map['createdAt'] ?? map['CreatedAt']),
      updatedAt: map['updated_at'] != null || map['updatedAt'] != null
          ? parseDateTime(map['updated_at'] ?? map['updatedAt'])
          : null,
    );
  }
}

enum AppointmentStatus { scheduled, confirmed, cancelled, completed }
