import 'dart:convert';

// مؤشرات الجودة (KPIs)
enum KPICategory {
  patientSafety, // سلامة المرضى
  clinicalOutcomes, // النتائج السريرية
  patientSatisfaction, // رضا المرضى
  operationalEfficiency, // الكفاءة التشغيلية
  financial, // مالي
  infectionControl, // مكافحة العدوى
  medicationSafety, // سلامة الأدوية
  other, // أخرى
}

enum KPIType {
  percentage, // نسبة مئوية
  count, // عدد
  rate, // معدل
  average, // متوسط
  time, // وقت
}

class KPIModel {
  final String id;
  final String name;
  final String? arabicName;
  final String description;
  final KPICategory category;
  final KPIType type;
  final double? targetValue; // القيمة المستهدفة
  final double? currentValue; // القيمة الحالية
  final String? unit; // الوحدة (%, عدد, يوم, إلخ)
  final DateTime? lastUpdated;
  final String? updatedBy;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;

  KPIModel({
    required this.id,
    required this.name,
    this.arabicName,
    required this.description,
    required this.category,
    required this.type,
    this.targetValue,
    this.currentValue,
    this.unit,
    this.lastUpdated,
    this.updatedBy,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory KPIModel.fromMap(Map<String, dynamic> map, String id) {
    final categoryStr = (map['category'] ?? 'other') as String;
    final typeStr = (map['type'] ?? 'count') as String;

    final category = KPICategory.values.firstWhere(
      (e) => e.toString().split('.').last == categoryStr,
      orElse: () => KPICategory.other,
    );
    final type = KPIType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => KPIType.count,
    );

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

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return KPIModel(
      id: id,
      name: map['name'] as String? ?? '',
      arabicName: map['arabicName'] as String? ?? map['arabic_name'] as String?,
      description: map['description'] as String? ?? '',
      category: category,
      type: type,
      targetValue: (map['targetValue'] ?? map['target_value']) as double?,
      currentValue: (map['currentValue'] ?? map['current_value']) as double?,
      unit: map['unit'] as String?,
      lastUpdated: parseDt(map['lastUpdated'] ?? map['last_updated']),
      updatedBy: map['updatedBy'] as String? ?? map['updated_by'] as String?,
      metadata: parseJson(map['metadata']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'arabicName': arabicName,
      'description': description,
      'category': category.toString().split('.').last,
      'type': type.toString().split('.').last,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'unit': unit,
      'lastUpdated': lastUpdated?.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// الحوادث الطبية
enum IncidentSeverity {
  low, // منخفضة
  medium, // متوسطة
  high, // عالية
  critical, // حرجة
}

enum IncidentStatus {
  reported, // تم الإبلاغ
  underInvestigation, // قيد التحقيق
  resolved, // تم الحل
  closed, // مغلق
}

enum IncidentType {
  medicationError, // خطأ دوائي
  fall, // سقوط
  infection, // عدوى
  equipmentFailure, // عطل معدات
  procedureError, // خطأ في الإجراء
  documentationError, // خطأ في التوثيق
  communicationError, // خطأ في التواصل
  other, // أخرى
}

class MedicalIncidentModel {
  final String id;
  final String? patientId;
  final String? patientName;
  final IncidentType type;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final String description;
  final String? location; // موقع الحادث
  final DateTime incidentDate;
  final DateTime? reportedDate;
  final String? reportedBy;
  final String? reportedByName;
  final String? investigationNotes;
  final String? resolutionNotes;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final List<String>? affectedPersons; // الأشخاص المتأثرين
  final Map<String, dynamic>? additionalData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MedicalIncidentModel({
    required this.id,
    this.patientId,
    this.patientName,
    required this.type,
    required this.severity,
    this.status = IncidentStatus.reported,
    required this.description,
    this.location,
    required this.incidentDate,
    this.reportedDate,
    this.reportedBy,
    this.reportedByName,
    this.investigationNotes,
    this.resolutionNotes,
    this.resolvedBy,
    this.resolvedAt,
    this.affectedPersons,
    this.additionalData,
    required this.createdAt,
    this.updatedAt,
  });

  factory MedicalIncidentModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'other') as String;
    final severityStr = (map['severity'] ?? 'medium') as String;
    final statusStr = (map['status'] ?? 'reported') as String;

    final type = IncidentType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => IncidentType.other,
    );
    final severity = IncidentSeverity.values.firstWhere(
      (e) => e.toString().split('.').last == severityStr,
      orElse: () => IncidentSeverity.medium,
    );
    final status = IncidentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => IncidentStatus.reported,
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

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return MedicalIncidentModel(
      id: id,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String?,
      patientName: map['patientName'] as String? ?? map['patient_name'] as String?,
      type: type,
      severity: severity,
      status: status,
      description: map['description'] as String? ?? '',
      location: map['location'] as String?,
      incidentDate: parseDt(map['incidentDate'] ?? map['incident_date']) ?? DateTime.now(),
      reportedDate: parseDt(map['reportedDate'] ?? map['reported_date']),
      reportedBy: map['reportedBy'] as String? ?? map['reported_by'] as String?,
      reportedByName: map['reportedByName'] as String? ?? map['reported_by_name'] as String?,
      investigationNotes: map['investigationNotes'] as String? ?? map['investigation_notes'] as String?,
      resolutionNotes: map['resolutionNotes'] as String? ?? map['resolution_notes'] as String?,
      resolvedBy: map['resolvedBy'] as String? ?? map['resolved_by'] as String?,
      resolvedAt: parseDt(map['resolvedAt'] ?? map['resolved_at']),
      affectedPersons: parseStringList(map['affectedPersons'] ?? map['affected_persons']),
      additionalData: parseJson(map['additionalData'] ?? map['additional_data']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'type': type.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'status': status.toString().split('.').last,
      'description': description,
      'location': location,
      'incidentDate': incidentDate.millisecondsSinceEpoch,
      'reportedDate': reportedDate?.millisecondsSinceEpoch,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'investigationNotes': investigationNotes,
      'resolutionNotes': resolutionNotes,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      'affectedPersons': affectedPersons != null ? jsonEncode(affectedPersons) : null,
      'additionalData': additionalData != null ? jsonEncode(additionalData) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// الشكاوى
enum ComplaintStatus {
  new, // جديدة
  inProgress, // قيد المعالجة
  resolved, // تم الحل
  closed, // مغلق
  rejected, // مرفوضة
}

enum ComplaintCategory {
  service, // خدمة
  staff, // موظفين
  facility, // مرافق
  billing, // فواتير
  medical, // طبي
  other, // أخرى
}

class ComplaintModel {
  final String id;
  final String? patientId;
  final String? patientName;
  final String? complainantName; // اسم الشاكي
  final String? complainantPhone; // هاتف الشاكي
  final String? complainantEmail; // بريد الشاكي
  final ComplaintCategory category;
  final ComplaintStatus status;
  final String subject;
  final String description;
  final String? department; // القسم المعني
  final String? assignedTo; // محال إلى
  final String? assignedToName;
  final String? response; // الرد
  final String? respondedBy;
  final DateTime? respondedAt;
  final DateTime complaintDate;
  final DateTime? resolvedAt;
  final Map<String, dynamic>? additionalData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ComplaintModel({
    required this.id,
    this.patientId,
    this.patientName,
    this.complainantName,
    this.complainantPhone,
    this.complainantEmail,
    required this.category,
    this.status = ComplaintStatus.new,
    required this.subject,
    required this.description,
    this.department,
    this.assignedTo,
    this.assignedToName,
    this.response,
    this.respondedBy,
    this.respondedAt,
    required this.complaintDate,
    this.resolvedAt,
    this.additionalData,
    required this.createdAt,
    this.updatedAt,
  });

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String id) {
    final categoryStr = (map['category'] ?? 'other') as String;
    final statusStr = (map['status'] ?? 'new') as String;

    final category = ComplaintCategory.values.firstWhere(
      (e) => e.toString().split('.').last == categoryStr,
      orElse: () => ComplaintCategory.other,
    );
    final status = ComplaintStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => ComplaintStatus.new,
    );

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

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return ComplaintModel(
      id: id,
      patientId: map['patientId'] as String? ?? map['patient_id'] as String?,
      patientName: map['patientName'] as String? ?? map['patient_name'] as String?,
      complainantName: map['complainantName'] as String? ?? map['complainant_name'] as String?,
      complainantPhone: map['complainantPhone'] as String? ?? map['complainant_phone'] as String?,
      complainantEmail: map['complainantEmail'] as String? ?? map['complainant_email'] as String?,
      category: category,
      status: status,
      subject: map['subject'] as String? ?? '',
      description: map['description'] as String? ?? '',
      department: map['department'] as String?,
      assignedTo: map['assignedTo'] as String? ?? map['assigned_to'] as String?,
      assignedToName: map['assignedToName'] as String? ?? map['assigned_to_name'] as String?,
      response: map['response'] as String?,
      respondedBy: map['respondedBy'] as String? ?? map['responded_by'] as String?,
      respondedAt: parseDt(map['respondedAt'] ?? map['responded_at']),
      complaintDate: parseDt(map['complaintDate'] ?? map['complaint_date']) ?? DateTime.now(),
      resolvedAt: parseDt(map['resolvedAt'] ?? map['resolved_at']),
      additionalData: parseJson(map['additionalData'] ?? map['additional_data']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'complainantName': complainantName,
      'complainantPhone': complainantPhone,
      'complainantEmail': complainantEmail,
      'category': category.toString().split('.').last,
      'status': status.toString().split('.').last,
      'subject': subject,
      'description': description,
      'department': department,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'response': response,
      'respondedBy': respondedBy,
      'respondedAt': respondedAt?.millisecondsSinceEpoch,
      'complaintDate': complaintDate.millisecondsSinceEpoch,
      'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      'additionalData': additionalData != null ? jsonEncode(additionalData) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// متطلبات الاعتماد
enum AccreditationStandard {
  jci, // Joint Commission International
  cbahi, // المركز السعودي لاعتماد المنشآت الصحية
  iso, // ISO
  other, // أخرى
}

enum AccreditationStatus {
  notStarted, // لم يبدأ
  inProgress, // قيد التنفيذ
  compliant, // متوافق
  nonCompliant, // غير متوافق
  certified, // معتمد
}

class AccreditationRequirementModel {
  final String id;
  final AccreditationStandard standard;
  final String requirementCode; // رمز المتطلب
  final String title;
  final String description;
  final AccreditationStatus status;
  final String? evidence; // الأدلة
  final String? notes;
  final DateTime? complianceDate; // تاريخ التوافق
  final DateTime? certificationDate; // تاريخ الاعتماد
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? dueDate; // تاريخ الاستحقاق
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AccreditationRequirementModel({
    required this.id,
    required this.standard,
    required this.requirementCode,
    required this.title,
    required this.description,
    this.status = AccreditationStatus.notStarted,
    this.evidence,
    this.notes,
    this.complianceDate,
    this.certificationDate,
    this.assignedTo,
    this.assignedToName,
    this.dueDate,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory AccreditationRequirementModel.fromMap(Map<String, dynamic> map, String id) {
    final standardStr = (map['standard'] ?? 'other') as String;
    final statusStr = (map['status'] ?? 'notStarted') as String;

    final standard = AccreditationStandard.values.firstWhere(
      (e) => e.toString().split('.').last == standardStr,
      orElse: () => AccreditationStandard.other,
    );
    final status = AccreditationStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => AccreditationStatus.notStarted,
    );

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

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is DateTime) return v;
      return null;
    }

    return AccreditationRequirementModel(
      id: id,
      standard: standard,
      requirementCode: map['requirementCode'] as String? ?? map['requirement_code'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: status,
      evidence: map['evidence'] as String?,
      notes: map['notes'] as String?,
      complianceDate: parseDt(map['complianceDate'] ?? map['compliance_date']),
      certificationDate: parseDt(map['certificationDate'] ?? map['certification_date']),
      assignedTo: map['assignedTo'] as String? ?? map['assigned_to'] as String?,
      assignedToName: map['assignedToName'] as String? ?? map['assigned_to_name'] as String?,
      dueDate: parseDt(map['dueDate'] ?? map['due_date']),
      metadata: parseJson(map['metadata']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'standard': standard.toString().split('.').last,
      'requirementCode': requirementCode,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'evidence': evidence,
      'notes': notes,
      'complianceDate': complianceDate?.millisecondsSinceEpoch,
      'certificationDate': certificationDate?.millisecondsSinceEpoch,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

