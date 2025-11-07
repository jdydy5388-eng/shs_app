class Medication {
  final String id;
  final String name;
  final String dosage;
  final String frequency; // e.g., "مرتين يومياً", "كل 8 ساعات"
  final String duration; // e.g., "7 أيام"
  final String instructions; // تعليمات إضافية
  final int quantity;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.instructions = '',
    required this.quantity,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      duration: map['duration'] ?? '',
      instructions: map['instructions'] ?? '',
      quantity: map['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'quantity': quantity,
    };
  }
}

enum PrescriptionStatus { pending, active, completed, cancelled }

class PrescriptionModel {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientId;
  final String patientName;
  final String diagnosis;
  final List<Medication> medications;
  final List<String>? drugInteractions; // تحذيرات التفاعلات الدوائية
  final String? notes;
  final PrescriptionStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  PrescriptionModel({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.patientId,
    required this.patientName,
    required this.diagnosis,
    required this.medications,
    this.drugInteractions,
    this.notes,
    required this.status,
    required this.createdAt,
    this.expiresAt,
  });

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    // فقط إذا كان Firebase Timestamp (وليس DateTime)
    try {
      if (v.runtimeType.toString().contains('Timestamp')) {
        final toDate = (v as dynamic).toDate();
        if (toDate is DateTime) return toDate;
      }
    } catch (_) {}
    return null;
  }

  factory PrescriptionModel.fromMap(Map<String, dynamic> map, String id) {
    return PrescriptionModel(
      id: id,
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      diagnosis: map['diagnosis'] ?? '',
      medications: (map['medications'] as List?)
              ?.map((m) => Medication.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      drugInteractions: map['drugInteractions'] != null
          ? List<String>.from(map['drugInteractions'])
          : null,
      notes: map['notes'],
      status: PrescriptionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => PrescriptionStatus.pending,
      ),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      expiresAt: _parseDateTime(map['expiresAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientId': patientId,
      'patientName': patientName,
      'diagnosis': diagnosis,
      'medications': medications.map((m) => m.toMap()).toList(),
      'drugInteractions': drugInteractions,
      'notes': notes,
      'status': status.toString().split('.').last,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    };
  }
}

