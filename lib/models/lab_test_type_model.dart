import 'dart:convert';

enum LabTestCategory {
  hematology, // أمراض الدم
  biochemistry, // كيمياء حيوية
  microbiology, // ميكروبيولوجيا
  immunology, // مناعة
  pathology, // علم الأمراض
  serology, // مصلية
  urinalysis, // تحليل البول
  other, // أخرى
}

enum LabTestPriority {
  routine, // روتيني
  urgent, // عاجل
  stat, // فوري
}

class LabTestTypeModel {
  final String id;
  final String name;
  final String? arabicName;
  final LabTestCategory category;
  final String? description;
  final double price;
  final int? estimatedDurationMinutes; // المدة المتوقعة بالدقائق
  final LabTestPriority defaultPriority;
  final List<String>? requiredSamples; // أنواع العينات المطلوبة
  final Map<String, dynamic>? normalRanges; // القيم الطبيعية
  final Map<String, dynamic>? criticalValues; // القيم الحرجة
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LabTestTypeModel({
    required this.id,
    required this.name,
    this.arabicName,
    required this.category,
    this.description,
    required this.price,
    this.estimatedDurationMinutes,
    this.defaultPriority = LabTestPriority.routine,
    this.requiredSamples,
    this.normalRanges,
    this.criticalValues,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory LabTestTypeModel.fromMap(Map<String, dynamic> map, String id) {
    final categoryStr = (map['category'] ?? 'other') as String;
    final priorityStr = (map['defaultPriority'] ?? map['default_priority'] ?? 'routine') as String;

    final category = LabTestCategory.values.firstWhere(
      (e) => e.toString().split('.').last == categoryStr,
      orElse: () => LabTestCategory.other,
    );

    final priority = LabTestPriority.values.firstWhere(
      (e) => e.toString().split('.').last == priorityStr,
      orElse: () => LabTestPriority.routine,
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

    return LabTestTypeModel(
      id: id,
      name: map['name'] as String? ?? '',
      arabicName: map['arabicName'] as String? ?? map['arabic_name'] as String?,
      category: category,
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationMinutes: (map['estimatedDurationMinutes'] as num?)?.toInt() ?? 
          (map['estimated_duration_minutes'] as int?),
      defaultPriority: priority,
      requiredSamples: parseStringList(map['requiredSamples'] ?? map['required_samples']),
      normalRanges: parseJson(map['normalRanges'] ?? map['normal_ranges']),
      criticalValues: parseJson(map['criticalValues'] ?? map['critical_values']),
      isActive: (map['isActive'] as bool?) ?? (map['is_active'] as bool?) ?? true,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'arabicName': arabicName,
      'category': category.toString().split('.').last,
      'description': description,
      'price': price,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'defaultPriority': defaultPriority.toString().split('.').last,
      'requiredSamples': requiredSamples != null ? jsonEncode(requiredSamples) : null,
      'normalRanges': normalRanges != null ? jsonEncode(normalRanges) : null,
      'criticalValues': criticalValues != null ? jsonEncode(criticalValues) : null,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

enum LabSampleStatus {
  collected, // تم جمعها
  received, // مستلمة
  processing, // قيد المعالجة
  completed, // مكتملة
  rejected, // مرفوضة
}

enum LabSampleType {
  blood, // دم
  urine, // بول
  stool, // براز
  sputum, // بلغم
  swab, // مسحة
  tissue, // نسيج
  other, // أخرى
}

class LabSampleModel {
  final String id;
  final String labRequestId;
  final LabSampleType type;
  final LabSampleStatus status;
  final String? collectionLocation; // مكان الجمع (الغرفة، السرير)
  final DateTime? collectedAt;
  final String? collectedBy;
  final DateTime? receivedAt;
  final String? receivedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LabSampleModel({
    required this.id,
    required this.labRequestId,
    required this.type,
    required this.status,
    this.collectionLocation,
    this.collectedAt,
    this.collectedBy,
    this.receivedAt,
    this.receivedBy,
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

  factory LabSampleModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'other') as String;
    final statusStr = (map['status'] ?? 'collected') as String;

    final type = LabSampleType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => LabSampleType.other,
    );

    final status = LabSampleStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => LabSampleStatus.collected,
    );

    return LabSampleModel(
      id: id,
      labRequestId: map['labRequestId'] as String? ?? map['lab_request_id'] as String? ?? '',
      type: type,
      status: status,
      collectionLocation: map['collectionLocation'] as String? ?? map['collection_location'] as String?,
      collectedAt: _parseDt(map['collectedAt'] ?? map['collected_at']),
      collectedBy: map['collectedBy'] as String? ?? map['collected_by'] as String?,
      receivedAt: _parseDt(map['receivedAt'] ?? map['received_at']),
      receivedBy: map['receivedBy'] as String? ?? map['received_by'] as String?,
      notes: map['notes'] as String?,
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'labRequestId': labRequestId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'collectionLocation': collectionLocation,
      'collectedAt': collectedAt?.millisecondsSinceEpoch,
      'collectedBy': collectedBy,
      'receivedAt': receivedAt?.millisecondsSinceEpoch,
      'receivedBy': receivedBy,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

class LabResultModel {
  final String id;
  final String labRequestId;
  final Map<String, dynamic> results; // النتائج (اسم الفحص: القيمة)
  final String? interpretation; // التفسير
  final bool isCritical; // هل النتائج حرجة؟
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LabResultModel({
    required this.id,
    required this.labRequestId,
    required this.results,
    this.interpretation,
    this.isCritical = false,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is DateTime) return v;
    return null;
  }

  factory LabResultModel.fromMap(Map<String, dynamic> map, String id) {
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

    return LabResultModel(
      id: id,
      labRequestId: map['labRequestId'] as String? ?? map['lab_request_id'] as String? ?? '',
      results: parseJson(map['results']) ?? {},
      interpretation: map['interpretation'] as String?,
      isCritical: (map['isCritical'] as bool?) ?? (map['is_critical'] as bool?) ?? false,
      reviewedBy: map['reviewedBy'] as String? ?? map['reviewed_by'] as String?,
      reviewedAt: _parseDt(map['reviewedAt'] ?? map['reviewed_at']),
      createdAt: _parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'labRequestId': labRequestId,
      'results': jsonEncode(results),
      'interpretation': interpretation,
      'isCritical': isCritical,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

