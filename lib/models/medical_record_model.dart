enum RecordType { 
  diagnosis, 
  labResult, 
  xray, 
  prescription, 
  note, 
  vaccination,
  surgery 
}

class MedicalRecordModel {
  final String id;
  final String patientId;
  final String? doctorId;
  final String? doctorName;
  final RecordType type;
  final String title;
  final String description;
  final DateTime date;
  final List<String>? fileUrls; // روابط الملفات (PDF, Images)
  final Map<String, dynamic>? additionalData; // بيانات إضافية حسب النوع
  final DateTime createdAt;

  MedicalRecordModel({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.doctorName,
    required this.type,
    required this.title,
    required this.description,
    required this.date,
    this.fileUrls,
    this.additionalData,
    required this.createdAt,
  });

  factory MedicalRecordModel.fromMap(Map<String, dynamic> map, String id) {
    // date parsing
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
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
      return DateTime.now();
    }

    List<String>? parseFileUrls(dynamic v) {
      if (v == null) return null;
      if (v is List) {
        return v.map((e) => '$e').toList();
      }
      return null;
    }

    Map<String, dynamic>? parseAdditional(dynamic v) {
      if (v == null) return null;
      if (v is Map) return Map<String, dynamic>.from(v as Map);
      return null;
    }

    return MedicalRecordModel(
      id: id,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'],
      doctorName: map['doctorName'],
      type: RecordType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => RecordType.note,
      ),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: parseDate(map['date']),
      fileUrls: parseFileUrls(map['fileUrls']),
      additionalData: parseAdditional(map['additionalData']),
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'date': date,
      'fileUrls': fileUrls,
      'additionalData': additionalData,
      'createdAt': createdAt,
    };
  }
}

