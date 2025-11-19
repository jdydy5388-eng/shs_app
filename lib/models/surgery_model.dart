import 'dart:convert';

enum SurgeryStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
  postponed,
}

enum SurgeryType {
  elective, // اختياري
  emergency, // طارئ
  urgent, // عاجل
}

class SurgeryModel {
  final String id;
  final String patientId;
  final String patientName;
  final String surgeryName;
  final SurgeryType type;
  final SurgeryStatus status;
  final DateTime scheduledDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? operationRoomId;
  final String? operationRoomName;
  
  // فريق العملية
  final String surgeonId;
  final String surgeonName;
  final String? assistantSurgeonId;
  final String? assistantSurgeonName;
  final String? anesthesiologistId;
  final String? anesthesiologistName;
  final List<String>? nurseIds;
  final List<String>? nurseNames;
  
  // السجلات
  final Map<String, dynamic>? preOperativeNotes;
  final Map<String, dynamic>? operativeNotes;
  final Map<String, dynamic>? postOperativeNotes;
  
  // معلومات إضافية
  final String? diagnosis;
  final String? procedure;
  final String? notes;
  final List<String>? equipment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SurgeryModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.surgeryName,
    required this.type,
    required this.status,
    required this.scheduledDate,
    this.startTime,
    this.endTime,
    this.operationRoomId,
    this.operationRoomName,
    required this.surgeonId,
    required this.surgeonName,
    this.assistantSurgeonId,
    this.assistantSurgeonName,
    this.anesthesiologistId,
    this.anesthesiologistName,
    this.nurseIds,
    this.nurseNames,
    this.preOperativeNotes,
    this.operativeNotes,
    this.postOperativeNotes,
    this.diagnosis,
    this.procedure,
    this.notes,
    this.equipment,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  static List<String>? _parseStringList(dynamic v) {
    if (v == null) return null;
    if (v is List) return v.map((e) => '$e').toList();
    if (v is String) {
      try {
        final decoded = jsonDecode(v) as List;
        return decoded.map((e) => '$e').toList();
      } catch (_) {
        return [v];
      }
    }
    return null;
  }

  static Map<String, dynamic>? _parseMap(dynamic v) {
    if (v == null) return null;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String) {
      try {
        return Map<String, dynamic>.from(jsonDecode(v) as Map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  factory SurgeryModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'elective') as String;
    final statusStr = (map['status'] ?? 'scheduled') as String;
    
    final type = SurgeryType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => SurgeryType.elective,
    );
    
    final status = SurgeryStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => SurgeryStatus.scheduled,
    );

    return SurgeryModel(
      id: id,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String? ?? '',
      patientName: map['patientName'] as String? ?? map['patient_name'] as String? ?? '',
      surgeryName: map['surgeryName'] as String? ?? map['surgery_name'] as String? ?? '',
      type: type,
      status: status,
      scheduledDate: _parseDt(map['scheduledDate'] ?? map['scheduled_date']) ?? DateTime.now(),
      startTime: _parseDt(map['startTime'] ?? map['start_time']),
      endTime: _parseDt(map['endTime'] ?? map['end_time']),
      operationRoomId: map['operationRoomId'] as String? ?? map['operation_room_id'] as String?,
      operationRoomName: map['operationRoomName'] as String? ?? map['operation_room_name'] as String?,
      surgeonId: map['surgeonId'] as String? ?? map['surgeon_id'] as String? ?? '',
      surgeonName: map['surgeonName'] as String? ?? map['surgeon_name'] as String? ?? '',
      assistantSurgeonId: map['assistantSurgeonId'] as String? ?? map['assistant_surgeon_id'] as String?,
      assistantSurgeonName: map['assistantSurgeonName'] as String? ?? map['assistant_surgeon_name'] as String?,
      anesthesiologistId: map['anesthesiologistId'] as String? ?? map['anesthesiologist_id'] as String?,
      anesthesiologistName: map['anesthesiologistName'] as String? ?? map['anesthesiologist_name'] as String?,
      nurseIds: _parseStringList(map['nurseIds'] ?? map['nurse_ids']),
      nurseNames: _parseStringList(map['nurseNames'] ?? map['nurse_names']),
      preOperativeNotes: _parseMap(map['preOperativeNotes'] ?? map['pre_operative_notes']),
      operativeNotes: _parseMap(map['operativeNotes'] ?? map['operative_notes']),
      postOperativeNotes: _parseMap(map['postOperativeNotes'] ?? map['post_operative_notes']),
      diagnosis: map['diagnosis'] as String?,
      procedure: map['procedure'] as String?,
      notes: map['notes'] as String?,
      equipment: _parseStringList(map['equipment']),
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'surgeryName': surgeryName,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'scheduledDate': scheduledDate.millisecondsSinceEpoch,
      'startTime': startTime?.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'operationRoomId': operationRoomId,
      'operationRoomName': operationRoomName,
      'surgeonId': surgeonId,
      'surgeonName': surgeonName,
      'assistantSurgeonId': assistantSurgeonId,
      'assistantSurgeonName': assistantSurgeonName,
      'anesthesiologistId': anesthesiologistId,
      'anesthesiologistName': anesthesiologistName,
      'nurseIds': nurseIds,
      'nurseNames': nurseNames,
      'preOperativeNotes': preOperativeNotes,
      'operativeNotes': operativeNotes,
      'postOperativeNotes': postOperativeNotes,
      'diagnosis': diagnosis,
      'procedure': procedure,
      'notes': notes,
      'equipment': equipment,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

