import 'dart:convert';

class NursingNoteModel {
  final String id;
  final String nurseId;
  final String? nurseName;
  final String patientId;
  final String? patientName;
  final String? bedId;
  final String? roomId;
  final String note;
  final Map<String, dynamic>? vitalSigns; // العلامات الحيوية
  final String? observations; // الملاحظات
  final DateTime createdAt;
  final DateTime? updatedAt;

  NursingNoteModel({
    required this.id,
    required this.nurseId,
    this.nurseName,
    required this.patientId,
    this.patientName,
    this.bedId,
    this.roomId,
    required this.note,
    this.vitalSigns,
    this.observations,
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

  factory NursingNoteModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, dynamic>? vitalSigns;
    if (map['vital_signs'] != null) {
      if (map['vital_signs'] is Map) {
        vitalSigns = Map<String, dynamic>.from(map['vital_signs'] as Map);
      } else if (map['vital_signs'] is String) {
        try {
          vitalSigns = Map<String, dynamic>.from(
            jsonDecode(map['vital_signs'] as String) as Map,
          );
        } catch (_) {
          vitalSigns = null;
        }
      }
    }

    return NursingNoteModel(
      id: id,
      nurseId: map['nurse_id'] as String? ?? map['nurseId'] as String? ?? '',
      nurseName: map['nurse_name'] as String? ?? map['nurseName'] as String?,
      patientId: map['patient_id'] as String? ?? map['patientId'] as String? ?? '',
      patientName: map['patient_name'] as String? ?? map['patientName'] as String?,
      bedId: map['bed_id'] as String? ?? map['bedId'] as String?,
      roomId: map['room_id'] as String? ?? map['roomId'] as String?,
      note: map['note'] as String? ?? '',
      vitalSigns: vitalSigns,
      observations: map['observations'] as String?,
      createdAt: _parseDateTimeRequired(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nurse_id': nurseId,
      'nurse_name': nurseName,
      'patient_id': patientId,
      'patient_name': patientName,
      'bed_id': bedId,
      'room_id': roomId,
      'note': note,
      'vital_signs': vitalSigns != null ? jsonEncode(vitalSigns) : null,
      'observations': observations,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

