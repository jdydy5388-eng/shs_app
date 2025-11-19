import 'dart:convert';

// طلبات الصيانة
enum MaintenanceRequestType {
  corrective, // تصحيحية
  preventive, // وقائية
  emergency, // طارئة
  inspection, // فحص
}

enum MaintenanceRequestStatus {
  pending, // قيد الانتظار
  assigned, // مكلفة
  inProgress, // قيد التنفيذ
  completed, // مكتملة
  cancelled, // ملغاة
}

enum MaintenancePriority {
  low, // منخفضة
  medium, // متوسطة
  high, // عالية
  urgent, // عاجلة
}

class MaintenanceRequestModel {
  final String id;
  final String? equipmentId; // معرف المعدة
  final String? equipmentName; // اسم المعدة
  final String? location; // الموقع
  final MaintenanceRequestType type;
  final MaintenanceRequestStatus status;
  final MaintenancePriority priority;
  final String description; // وصف المشكلة
  final String? reportedBy; // من أبلغ
  final String? reportedByName;
  final DateTime reportedDate; // تاريخ الإبلاغ
  final String? assignedTo; // مكلف إلى
  final String? assignedToName;
  final DateTime? assignedDate;
  final DateTime? scheduledDate; // تاريخ مجدول
  final DateTime? completedDate; // تاريخ الإكمال
  final String? completedBy;
  final String? completedByName;
  final String? workPerformed; // العمل المنفذ
  final String? notes; // ملاحظات
  final double? cost; // التكلفة
  final List<String>? attachments; // مرفقات
  final Map<String, dynamic>? additionalData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MaintenanceRequestModel({
    required this.id,
    this.equipmentId,
    this.equipmentName,
    this.location,
    required this.type,
    this.status = MaintenanceRequestStatus.pending,
    this.priority = MaintenancePriority.medium,
    required this.description,
    this.reportedBy,
    this.reportedByName,
    required this.reportedDate,
    this.assignedTo,
    this.assignedToName,
    this.assignedDate,
    this.scheduledDate,
    this.completedDate,
    this.completedBy,
    this.completedByName,
    this.workPerformed,
    this.notes,
    this.cost,
    this.attachments,
    this.additionalData,
    required this.createdAt,
    this.updatedAt,
  });

  factory MaintenanceRequestModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'corrective') as String;
    final statusStr = (map['status'] ?? 'pending') as String;
    final priorityStr = (map['priority'] ?? 'medium') as String;

    final type = MaintenanceRequestType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => MaintenanceRequestType.corrective,
    );
    final status = MaintenanceRequestStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => MaintenanceRequestStatus.pending,
    );
    final priority = MaintenancePriority.values.firstWhere(
      (e) => e.toString().split('.').last == priorityStr,
      orElse: () => MaintenancePriority.medium,
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

    return MaintenanceRequestModel(
      id: id,
      equipmentId: map['equipmentId'] as String? ?? map['equipment_id'] as String?,
      equipmentName: map['equipmentName'] as String? ?? map['equipment_name'] as String?,
      location: map['location'] as String?,
      type: type,
      status: status,
      priority: priority,
      description: map['description'] as String? ?? '',
      reportedBy: map['reportedBy'] as String? ?? map['reported_by'] as String?,
      reportedByName: map['reportedByName'] as String? ?? map['reported_by_name'] as String?,
      reportedDate: parseDt(map['reportedDate'] ?? map['reported_date']) ?? DateTime.now(),
      assignedTo: map['assignedTo'] as String? ?? map['assigned_to'] as String?,
      assignedToName: map['assignedToName'] as String? ?? map['assigned_to_name'] as String?,
      assignedDate: parseDt(map['assignedDate'] ?? map['assigned_date']),
      scheduledDate: parseDt(map['scheduledDate'] ?? map['scheduled_date']),
      completedDate: parseDt(map['completedDate'] ?? map['completed_date']),
      completedBy: map['completedBy'] as String? ?? map['completed_by'] as String?,
      completedByName: map['completedByName'] as String? ?? map['completed_by_name'] as String?,
      workPerformed: map['workPerformed'] as String? ?? map['work_performed'] as String?,
      notes: map['notes'] as String?,
      cost: (map['cost'] as num?)?.toDouble(),
      attachments: parseStringList(map['attachments']),
      additionalData: parseJson(map['additionalData'] ?? map['additional_data']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'location': location,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'description': description,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'reportedDate': reportedDate.millisecondsSinceEpoch,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedDate': assignedDate?.millisecondsSinceEpoch,
      'scheduledDate': scheduledDate?.millisecondsSinceEpoch,
      'completedDate': completedDate?.millisecondsSinceEpoch,
      'completedBy': completedBy,
      'completedByName': completedByName,
      'workPerformed': workPerformed,
      'notes': notes,
      'cost': cost,
      'attachments': attachments != null ? jsonEncode(attachments) : null,
      'additionalData': additionalData != null ? jsonEncode(additionalData) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// الصيانة الدورية المجدولة
enum ScheduledMaintenanceFrequency {
  daily, // يومي
  weekly, // أسبوعي
  monthly, // شهري
  quarterly, // ربع سنوي
  semiAnnual, // نصف سنوي
  annual, // سنوي
  custom, // مخصص
}

enum ScheduledMaintenanceStatus {
  scheduled, // مجدول
  inProgress, // قيد التنفيذ
  completed, // مكتمل
  skipped, // تم التخطي
  cancelled, // ملغى
}

class ScheduledMaintenanceModel {
  final String id;
  final String equipmentId; // معرف المعدة
  final String? equipmentName; // اسم المعدة
  final String maintenanceType; // نوع الصيانة
  final String description; // الوصف
  final ScheduledMaintenanceFrequency frequency; // التكرار
  final int? intervalDays; // عدد الأيام (للتكرار المخصص)
  final DateTime nextDueDate; // تاريخ الاستحقاق القادم
  final DateTime? lastPerformedDate; // تاريخ آخر تنفيذ
  final String? lastPerformedBy; // من نفذ آخر مرة
  final ScheduledMaintenanceStatus status;
  final String? assignedTo; // مكلف إلى
  final String? assignedToName;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ScheduledMaintenanceModel({
    required this.id,
    required this.equipmentId,
    this.equipmentName,
    required this.maintenanceType,
    required this.description,
    required this.frequency,
    this.intervalDays,
    required this.nextDueDate,
    this.lastPerformedDate,
    this.lastPerformedBy,
    this.status = ScheduledMaintenanceStatus.scheduled,
    this.assignedTo,
    this.assignedToName,
    this.notes,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory ScheduledMaintenanceModel.fromMap(Map<String, dynamic> map, String id) {
    final frequencyStr = (map['frequency'] ?? 'monthly') as String;
    final statusStr = (map['status'] ?? 'scheduled') as String;

    final frequency = ScheduledMaintenanceFrequency.values.firstWhere(
      (e) => e.toString().split('.').last == frequencyStr,
      orElse: () => ScheduledMaintenanceFrequency.monthly,
    );
    final status = ScheduledMaintenanceStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => ScheduledMaintenanceStatus.scheduled,
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

    return ScheduledMaintenanceModel(
      id: id,
      equipmentId: map['equipmentId'] as String? ?? map['equipment_id'] as String? ?? '',
      equipmentName: map['equipmentName'] as String? ?? map['equipment_name'] as String?,
      maintenanceType: map['maintenanceType'] as String? ?? map['maintenance_type'] as String? ?? '',
      description: map['description'] as String? ?? '',
      frequency: frequency,
      intervalDays: (map['intervalDays'] ?? map['interval_days'] as num?)?.toInt(),
      nextDueDate: parseDt(map['nextDueDate'] ?? map['next_due_date']) ?? DateTime.now(),
      lastPerformedDate: parseDt(map['lastPerformedDate'] ?? map['last_performed_date']),
      lastPerformedBy: map['lastPerformedBy'] as String? ?? map['last_performed_by'] as String?,
      status: status,
      assignedTo: map['assignedTo'] as String? ?? map['assigned_to'] as String?,
      assignedToName: map['assignedToName'] as String? ?? map['assigned_to_name'] as String?,
      notes: map['notes'] as String?,
      metadata: parseJson(map['metadata']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'maintenanceType': maintenanceType,
      'description': description,
      'frequency': frequency.toString().split('.').last,
      'intervalDays': intervalDays,
      'nextDueDate': nextDueDate.millisecondsSinceEpoch,
      'lastPerformedDate': lastPerformedDate?.millisecondsSinceEpoch,
      'lastPerformedBy': lastPerformedBy,
      'status': status.toString().split('.').last,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'notes': notes,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// حالة المعدات
enum EquipmentCondition {
  excellent, // ممتاز
  good, // جيد
  fair, // مقبول
  poor, // ضعيف
  critical, // حرج
  outOfService, // خارج الخدمة
}

class EquipmentStatusModel {
  final String id;
  final String equipmentId; // معرف المعدة
  final String? equipmentName; // اسم المعدة
  final EquipmentCondition condition; // الحالة
  final String? location; // الموقع
  final DateTime lastMaintenanceDate; // تاريخ آخر صيانة
  final DateTime? nextMaintenanceDate; // تاريخ الصيانة القادمة
  final int? totalMaintenanceCount; // عدد مرات الصيانة
  final double? totalMaintenanceCost; // إجمالي تكلفة الصيانة
  final String? currentIssues; // المشاكل الحالية
  final String? notes;
  final Map<String, dynamic>? statusData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EquipmentStatusModel({
    required this.id,
    required this.equipmentId,
    this.equipmentName,
    required this.condition,
    this.location,
    required this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.totalMaintenanceCount,
    this.totalMaintenanceCost,
    this.currentIssues,
    this.notes,
    this.statusData,
    required this.createdAt,
    this.updatedAt,
  });

  factory EquipmentStatusModel.fromMap(Map<String, dynamic> map, String id) {
    final conditionStr = (map['condition'] ?? 'good') as String;

    final condition = EquipmentCondition.values.firstWhere(
      (e) => e.toString().split('.').last == conditionStr,
      orElse: () => EquipmentCondition.good,
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

    return EquipmentStatusModel(
      id: id,
      equipmentId: map['equipmentId'] as String? ?? map['equipment_id'] as String? ?? '',
      equipmentName: map['equipmentName'] as String? ?? map['equipment_name'] as String?,
      condition: condition,
      location: map['location'] as String?,
      lastMaintenanceDate: parseDt(map['lastMaintenanceDate'] ?? map['last_maintenance_date']) ?? DateTime.now(),
      nextMaintenanceDate: parseDt(map['nextMaintenanceDate'] ?? map['next_maintenance_date']),
      totalMaintenanceCount: (map['totalMaintenanceCount'] ?? map['total_maintenance_count'] as num?)?.toInt(),
      totalMaintenanceCost: (map['totalMaintenanceCost'] ?? map['total_maintenance_cost'] as num?)?.toDouble(),
      currentIssues: map['currentIssues'] as String? ?? map['current_issues'] as String?,
      notes: map['notes'] as String?,
      statusData: parseJson(map['statusData'] ?? map['status_data']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'condition': condition.toString().split('.').last,
      'location': location,
      'lastMaintenanceDate': lastMaintenanceDate.millisecondsSinceEpoch,
      'nextMaintenanceDate': nextMaintenanceDate?.millisecondsSinceEpoch,
      'totalMaintenanceCount': totalMaintenanceCount,
      'totalMaintenanceCost': totalMaintenanceCost,
      'currentIssues': currentIssues,
      'notes': notes,
      'statusData': statusData != null ? jsonEncode(statusData) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// موردين الصيانة
enum MaintenanceVendorType {
  internal, // داخلي
  external, // خارجي
}

class MaintenanceVendorModel {
  final String id;
  final String name; // اسم المورد
  final MaintenanceVendorType type; // النوع
  final String? contactPerson; // الشخص المسؤول
  final String? email; // البريد الإلكتروني
  final String? phone; // الهاتف
  final String? address; // العنوان
  final String? specialization; // التخصص
  final String? notes; // ملاحظات
  final bool isActive; // نشط
  final Map<String, dynamic>? additionalInfo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MaintenanceVendorModel({
    required this.id,
    required this.name,
    required this.type,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.specialization,
    this.notes,
    this.isActive = true,
    this.additionalInfo,
    required this.createdAt,
    this.updatedAt,
  });

  factory MaintenanceVendorModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'external') as String;

    final type = MaintenanceVendorType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => MaintenanceVendorType.external,
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

    return MaintenanceVendorModel(
      id: id,
      name: map['name'] as String? ?? '',
      type: type,
      contactPerson: map['contactPerson'] as String? ?? map['contact_person'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      specialization: map['specialization'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['isActive'] ?? map['is_active'] as num?)?.toInt() == 1,
      additionalInfo: parseJson(map['additionalInfo'] ?? map['additional_info']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
      'specialization': specialization,
      'notes': notes,
      'isActive': isActive ? 1 : 0,
      'additionalInfo': additionalInfo != null ? jsonEncode(additionalInfo) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

