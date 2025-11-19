import 'dart:convert';

enum DocumentCategory {
  medicalRecord, // سجل طبي
  labResult, // نتيجة مختبرية
  radiologyReport, // تقرير أشعة
  prescription, // وصفة طبية
  surgeryReport, // تقرير عملية
  dischargeSummary, // ملخص الخروج
  consentForm, // نموذج موافقة
  insuranceDocument, // وثيقة تأمين
  administrative, // إداري
  other, // أخرى
}

enum DocumentStatus {
  draft, // مسودة
  active, // نشط
  archived, // مؤرشف
  deleted, // محذوف
}

enum DocumentAccessLevel {
  private, // خاص (المالك فقط)
  shared, // مشترك (مع أطباء محددين)
  department, // القسم
  hospital, // المستشفى
}

class DocumentModel {
  final String id;
  final String title;
  final String? description;
  final DocumentCategory category;
  final DocumentStatus status;
  final DocumentAccessLevel accessLevel;
  final String? patientId;
  final String? patientName;
  final String? doctorId;
  final String? doctorName;
  final List<String>? sharedWithUserIds; // مستخدمون يمكنهم الوصول
  final List<String>? tags; // علامات للبحث
  final String fileUrl;
  final String fileName;
  final String? fileType; // pdf, image, etc.
  final int? fileSize; // بالبايت
  final String? thumbnailUrl; // صورة مصغرة
  final Map<String, dynamic>? metadata; // بيانات إضافية
  final String? signatureId; // معرف التوقيع الإلكتروني
  final DateTime? signedAt; // تاريخ التوقيع
  final String? signedBy; // من وقع
  final DateTime? archivedAt; // تاريخ الأرشفة
  final String? archivedBy; // من أرشف
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  DocumentModel({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.status = DocumentStatus.active,
    this.accessLevel = DocumentAccessLevel.private,
    this.patientId,
    this.patientName,
    this.doctorId,
    this.doctorName,
    this.sharedWithUserIds,
    this.tags,
    required this.fileUrl,
    required this.fileName,
    this.fileType,
    this.fileSize,
    this.thumbnailUrl,
    this.metadata,
    this.signatureId,
    this.signedAt,
    this.signedBy,
    this.archivedAt,
    this.archivedBy,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map, String id) {
    final categoryStr = (map['category'] ?? 'other') as String;
    final statusStr = (map['status'] ?? 'active') as String;
    final accessLevelStr = (map['accessLevel'] ?? 'private') as String;

    final category = DocumentCategory.values.firstWhere(
      (e) => e.toString().split('.').last == categoryStr,
      orElse: () => DocumentCategory.other,
    );
    final status = DocumentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => DocumentStatus.active,
    );
    final accessLevel = DocumentAccessLevel.values.firstWhere(
      (e) => e.toString().split('.').last == accessLevelStr,
      orElse: () => DocumentAccessLevel.private,
    );

    List<String>? parseStringList(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        try {
          return List<String>.from(jsonDecode(v) as List);
        } catch (_) {
          return null;
        }
      }
      if (v is List) return v.map((e) => e.toString()).toList();
      return null;
    }

    Map<String, dynamic>? parseJson(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        try {
          return jsonDecode(v) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    return DocumentModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      category: category,
      status: status,
      accessLevel: accessLevel,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String?,
      patientName: map['patientName'] as String? ?? map['patient_name'] as String?,
      doctorId: map['doctorId'] as String? ?? map['doctor_id'] as String?,
      doctorName: map['doctorName'] as String? ?? map['doctor_name'] as String?,
      sharedWithUserIds: parseStringList(map['sharedWithUserIds'] ?? map['shared_with_user_ids']),
      tags: parseStringList(map['tags']),
      fileUrl: map['fileUrl'] as String? ?? map['file_url'] as String? ?? '',
      fileName: map['fileName'] as String? ?? map['file_name'] as String? ?? '',
      fileType: map['fileType'] as String? ?? map['file_type'] as String?,
      fileSize: map['fileSize'] as int? ?? map['file_size'] as int?,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? map['thumbnail_url'] as String?,
      metadata: parseJson(map['metadata']),
      signatureId: map['signatureId'] as String? ?? map['signature_id'] as String?,
      signedAt: _parseDt(map['signedAt'] ?? map['signed_at']),
      signedBy: map['signedBy'] as String? ?? map['signed_by'] as String?,
      archivedAt: _parseDt(map['archivedAt'] ?? map['archived_at']),
      archivedBy: map['archivedBy'] as String? ?? map['archived_by'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
      createdBy: map['createdBy'] as String? ?? map['created_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.toString().split('.').last,
      'status': status.toString().split('.').last,
      'accessLevel': accessLevel.toString().split('.').last,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'sharedWithUserIds': sharedWithUserIds != null ? jsonEncode(sharedWithUserIds) : null,
      'tags': tags != null ? jsonEncode(tags) : null,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'signatureId': signatureId,
      'signedAt': signedAt?.millisecondsSinceEpoch,
      'signedBy': signedBy,
      'archivedAt': archivedAt?.millisecondsSinceEpoch,
      'archivedBy': archivedBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'createdBy': createdBy,
    };
  }

  DocumentModel copyWith({
    String? title,
    String? description,
    DocumentCategory? category,
    DocumentStatus? status,
    DocumentAccessLevel? accessLevel,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? doctorName,
    List<String>? sharedWithUserIds,
    List<String>? tags,
    String? fileUrl,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
    String? signatureId,
    DateTime? signedAt,
    String? signedBy,
    DateTime? archivedAt,
    String? archivedBy,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      accessLevel: accessLevel ?? this.accessLevel,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
      tags: tags ?? this.tags,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      signatureId: signatureId ?? this.signatureId,
      signedAt: signedAt ?? this.signedAt,
      signedBy: signedBy ?? this.signedBy,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
    );
  }
}

class DocumentSignature {
  final String id;
  final String documentId;
  final String signedBy;
  final String signedByName;
  final String signatureData; // بيانات التوقيع (صورة أو نص)
  final DateTime signedAt;
  final String? notes;

  DocumentSignature({
    required this.id,
    required this.documentId,
    required this.signedBy,
    required this.signedByName,
    required this.signatureData,
    required this.signedAt,
    this.notes,
  });

  factory DocumentSignature.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return DocumentSignature(
      id: id,
      documentId: map['documentId'] as String? ?? map['document_id'] as String? ?? '',
      signedBy: map['signedBy'] as String? ?? map['signed_by'] as String? ?? '',
      signedByName: map['signedByName'] as String? ?? map['signed_by_name'] as String? ?? '',
      signatureData: map['signatureData'] as String? ?? map['signature_data'] as String? ?? '',
      signedAt: parseDt(map['signedAt'] ?? map['signed_at']) ?? DateTime.now(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'signedBy': signedBy,
      'signedByName': signedByName,
      'signatureData': signatureData,
      'signedAt': signedAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }
}

