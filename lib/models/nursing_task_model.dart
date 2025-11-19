import 'dart:convert';

enum NursingTaskType {
  medication,      // إعطاء دواء
  vitalSigns,     // قياس العلامات الحيوية
  woundCare,      // العناية بالجروح
  patientCheck,   // فحص المريض
  documentation,  // توثيق
  other           // أخرى
}

enum NursingTaskStatus { pending, inProgress, completed, cancelled }

class NursingTaskModel {
  final String id;
  final String nurseId;
  final String? patientId;
  final String? patientName;
  final String? bedId;
  final String? roomId;
  final NursingTaskType type;
  final String title;
  final String? description;
  final NursingTaskStatus status;
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final String? completedBy;
  final Map<String, dynamic>? resultData; // بيانات النتيجة (مثل العلامات الحيوية)
  final DateTime createdAt;
  final DateTime? updatedAt;

  NursingTaskModel({
    required this.id,
    required this.nurseId,
    this.patientId,
    this.patientName,
    this.bedId,
    this.roomId,
    required this.type,
    required this.title,
    this.description,
    required this.status,
    required this.scheduledAt,
    this.completedAt,
    this.completedBy,
    this.resultData,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return null;
  }

  static DateTime _parseDateTimeRequired(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return DateTime.now();
  }

  factory NursingTaskModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] as String?) ?? 'other';
    final statusStr = (map['status'] as String?) ?? 'pending';
    
    final type = NursingTaskType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => NursingTaskType.other,
    );
    
    final status = NursingTaskStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => NursingTaskStatus.pending,
    );

    Map<String, dynamic>? resultData;
    if (map['result_data'] != null) {
      if (map['result_data'] is Map) {
        resultData = Map<String, dynamic>.from(map['result_data'] as Map);
      } else if (map['result_data'] is String) {
        try {
          resultData = Map<String, dynamic>.from(
            jsonDecode(map['result_data'] as String) as Map,
          );
        } catch (_) {
          resultData = null;
        }
      }
    }

    return NursingTaskModel(
      id: id,
      nurseId: map['nurse_id'] as String? ?? map['nurseId'] as String? ?? '',
      patientId: map['patient_id'] as String? ?? map['patientId'] as String?,
      patientName: map['patient_name'] as String? ?? map['patientName'] as String?,
      bedId: map['bed_id'] as String? ?? map['bedId'] as String?,
      roomId: map['room_id'] as String? ?? map['roomId'] as String?,
      type: type,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      status: status,
      scheduledAt: _parseDateTimeRequired(map['scheduled_at'] ?? map['scheduledAt']),
      completedAt: _parseDateTime(map['completed_at'] ?? map['completedAt']),
      completedBy: map['completed_by'] as String? ?? map['completedBy'] as String?,
      resultData: resultData,
      createdAt: _parseDateTimeRequired(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nurse_id': nurseId,
      'patient_id': patientId,
      'patient_name': patientName,
      'bed_id': bedId,
      'room_id': roomId,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'scheduled_at': scheduledAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'completed_by': completedBy,
      'result_data': resultData != null ? jsonEncode(resultData) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

