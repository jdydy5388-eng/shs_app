import 'dart:convert';

enum MedicationDispenseStatus {
  scheduled, // مجدولة
  dispensed, // تم الصرف
  missed, // فائتة
  cancelled, // ملغاة
}

enum MedicationScheduleType {
  scheduled, // مجدولة (حسب جدول)
  prn, // عند الحاجة (as needed)
  stat, // فورية
}

class HospitalPharmacyDispenseModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? bedId;
  final String? roomId;
  final String prescriptionId;
  final String medicationId;
  final String medicationName;
  final String dosage;
  final String frequency;
  final int quantity;
  final MedicationDispenseStatus status;
  final MedicationScheduleType scheduleType;
  final DateTime scheduledTime;
  final DateTime? dispensedAt;
  final String? dispensedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  HospitalPharmacyDispenseModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.bedId,
    this.roomId,
    required this.prescriptionId,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.quantity,
    required this.status,
    required this.scheduleType,
    required this.scheduledTime,
    this.dispensedAt,
    this.dispensedBy,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isOverdue => 
      status == MedicationDispenseStatus.scheduled && 
      scheduledTime.isBefore(DateTime.now());

  bool get isDueSoon {
    if (status != MedicationDispenseStatus.scheduled) return false;
    final timeUntilDue = scheduledTime.difference(DateTime.now());
    return timeUntilDue.inMinutes <= 30 && timeUntilDue.inMinutes >= 0;
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory HospitalPharmacyDispenseModel.fromMap(Map<String, dynamic> map, String id) {
    final statusStr = (map['status'] ?? 'scheduled') as String;
    final scheduleTypeStr = (map['scheduleType'] ?? map['schedule_type'] ?? 'scheduled') as String;

    final status = MedicationDispenseStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => MedicationDispenseStatus.scheduled,
    );

    final scheduleType = MedicationScheduleType.values.firstWhere(
      (e) => e.toString().split('.').last == scheduleTypeStr,
      orElse: () => MedicationScheduleType.scheduled,
    );

    return HospitalPharmacyDispenseModel(
      id: id,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String? ?? '',
      patientName: map['patientName'] as String? ?? map['patient_name'] as String? ?? '',
      bedId: map['bedId'] as String? ?? map['bed_id'] as String?,
      roomId: map['roomId'] as String? ?? map['room_id'] as String?,
      prescriptionId: map['prescriptionId'] as String? ?? map['prescription_id'] as String? ?? '',
      medicationId: map['medicationId'] as String? ?? map['medication_id'] as String? ?? '',
      medicationName: map['medicationName'] as String? ?? map['medication_name'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      status: status,
      scheduleType: scheduleType,
      scheduledTime: _parseDt(map['scheduledTime'] ?? map['scheduled_time']) ?? DateTime.now(),
      dispensedAt: _parseDt(map['dispensedAt'] ?? map['dispensed_at']),
      dispensedBy: map['dispensedBy'] as String? ?? map['dispensed_by'] as String?,
      notes: map['notes'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'bedId': bedId,
      'roomId': roomId,
      'prescriptionId': prescriptionId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'dosage': dosage,
      'frequency': frequency,
      'quantity': quantity,
      'status': status.toString().split('.').last,
      'scheduleType': scheduleType.toString().split('.').last,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'dispensedAt': dispensedAt?.millisecondsSinceEpoch,
      'dispensedBy': dispensedBy,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

class MedicationScheduleModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? bedId;
  final String? roomId;
  final String prescriptionId;
  final String medicationId;
  final String medicationName;
  final String dosage;
  final String frequency;
  final int quantity;
  final MedicationScheduleType scheduleType;
  final DateTime startDate;
  final DateTime? endDate;
  final List<DateTime> scheduledTimes; // قائمة الأوقات المجدولة
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MedicationScheduleModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.bedId,
    this.roomId,
    required this.prescriptionId,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.frequency,
    required this.quantity,
    required this.scheduleType,
    required this.startDate,
    this.endDate,
    required this.scheduledTimes,
    this.isActive = true,
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

  factory MedicationScheduleModel.fromMap(Map<String, dynamic> map, String id) {
    final scheduleTypeStr = (map['scheduleType'] ?? map['schedule_type'] ?? 'scheduled') as String;
    final scheduleType = MedicationScheduleType.values.firstWhere(
      (e) => e.toString().split('.').last == scheduleTypeStr,
      orElse: () => MedicationScheduleType.scheduled,
    );

    List<DateTime> scheduledTimes = [];
    if (map['scheduledTimes'] != null || map['scheduled_times'] != null) {
      final times = map['scheduledTimes'] ?? map['scheduled_times'];
      if (times is List) {
        scheduledTimes = times.map((t) => _parseDt(t) ?? DateTime.now()).toList();
      } else if (times is String) {
        try {
          final decoded = jsonDecode(times) as List;
          scheduledTimes = decoded.map((t) => _parseDt(t) ?? DateTime.now()).toList();
        } catch (_) {}
      }
    }

    return MedicationScheduleModel(
      id: id,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String? ?? '',
      patientName: map['patientName'] as String? ?? map['patient_name'] as String? ?? '',
      bedId: map['bedId'] as String? ?? map['bed_id'] as String?,
      roomId: map['roomId'] as String? ?? map['room_id'] as String?,
      prescriptionId: map['prescriptionId'] as String? ?? map['prescription_id'] as String? ?? '',
      medicationId: map['medicationId'] as String? ?? map['medication_id'] as String? ?? '',
      medicationName: map['medicationName'] as String? ?? map['medication_name'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      frequency: map['frequency'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      scheduleType: scheduleType,
      startDate: _parseDt(map['startDate'] ?? map['start_date']) ?? DateTime.now(),
      endDate: _parseDt(map['endDate'] ?? map['end_date']),
      scheduledTimes: scheduledTimes,
      isActive: (map['isActive'] as bool?) ?? (map['is_active'] as bool?) ?? true,
      notes: map['notes'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'bedId': bedId,
      'roomId': roomId,
      'prescriptionId': prescriptionId,
      'medicationId': medicationId,
      'medicationName': medicationName,
      'dosage': dosage,
      'frequency': frequency,
      'quantity': quantity,
      'scheduleType': scheduleType.toString().split('.').last,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'scheduledTimes': scheduledTimes.map((t) => t.millisecondsSinceEpoch).toList(),
      'isActive': isActive,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

