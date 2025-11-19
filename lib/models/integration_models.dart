import 'dart:convert';

// أنواع التكامل
enum IntegrationType {
  laboratory, // مختبر
  bank, // بنك
  insurance, // تأمين
  pharmacy, // صيدلية
  hospital, // مستشفى
  hl7, // HL7/FHIR
  other, // أخرى
}

// حالة التكامل
enum IntegrationStatus {
  active, // نشط
  inactive, // غير نشط
  error, // خطأ
  pending, // قيد الانتظار
}

// تكامل مع نظام خارجي
class ExternalIntegrationModel {
  final String id;
  final String name; // اسم التكامل
  final IntegrationType type;
  final IntegrationStatus status;
  final String? apiUrl; // رابط API
  final String? apiKey; // مفتاح API (مشفر)
  final String? apiSecret; // سر API (مشفر)
  final Map<String, dynamic>? config; // إعدادات إضافية
  final String? description; // وصف
  final DateTime? lastSync; // آخر مزامنة
  final String? lastSyncError; // آخر خطأ في المزامنة
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExternalIntegrationModel({
    required this.id,
    required this.name,
    required this.type,
    this.status = IntegrationStatus.pending,
    this.apiUrl,
    this.apiKey,
    this.apiSecret,
    this.config,
    this.description,
    this.lastSync,
    this.lastSyncError,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory ExternalIntegrationModel.fromMap(Map<String, dynamic> map, String id) {
    final typeStr = (map['type'] ?? 'other') as String;
    final statusStr = (map['status'] ?? 'pending') as String;

    final type = IntegrationType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => IntegrationType.other,
    );
    final status = IntegrationStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => IntegrationStatus.pending,
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

    return ExternalIntegrationModel(
      id: id,
      name: map['name'] as String? ?? '',
      type: type,
      status: status,
      apiUrl: map['apiUrl'] as String? ?? map['api_url'] as String?,
      apiKey: map['apiKey'] as String? ?? map['api_key'] as String?,
      apiSecret: map['apiSecret'] as String? ?? map['api_secret'] as String?,
      config: parseJson(map['config']),
      description: map['description'] as String?,
      lastSync: parseDt(map['lastSync'] ?? map['last_sync']),
      lastSyncError: map['lastSyncError'] as String? ?? map['last_sync_error'] as String?,
      metadata: parseJson(map['metadata']),
      createdAt: parseDt(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'config': config != null ? jsonEncode(config) : null,
      'description': description,
      'lastSync': lastSync?.millisecondsSinceEpoch,
      'lastSyncError': lastSyncError,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

// سجل مزامنة
class IntegrationSyncLogModel {
  final String id;
  final String integrationId; // معرف التكامل
  final String integrationName; // اسم التكامل
  final String syncType; // نوع المزامنة (send, receive, both)
  final bool success; // نجحت المزامنة
  final String? errorMessage; // رسالة الخطأ
  final int? recordsProcessed; // عدد السجلات المعالجة
  final Map<String, dynamic>? details; // تفاصيل إضافية
  final DateTime timestamp;

  IntegrationSyncLogModel({
    required this.id,
    required this.integrationId,
    required this.integrationName,
    required this.syncType,
    this.success = true,
    this.errorMessage,
    this.recordsProcessed,
    this.details,
    required this.timestamp,
  });

  factory IntegrationSyncLogModel.fromMap(Map<String, dynamic> map, String id) {
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

    return IntegrationSyncLogModel(
      id: id,
      integrationId: map['integrationId'] as String? ?? map['integration_id'] as String? ?? '',
      integrationName: map['integrationName'] as String? ?? map['integration_name'] as String? ?? '',
      syncType: map['syncType'] as String? ?? map['sync_type'] as String? ?? 'both',
      success: (map['success'] as bool?) ?? true,
      errorMessage: map['errorMessage'] as String? ?? map['error_message'] as String?,
      recordsProcessed: map['recordsProcessed'] as int? ?? map['records_processed'] as int?,
      details: parseJson(map['details']),
      timestamp: parseDt(map['timestamp']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'integrationId': integrationId,
      'integrationName': integrationName,
      'syncType': syncType,
      'success': success,
      'errorMessage': errorMessage,
      'recordsProcessed': recordsProcessed,
      'details': details != null ? jsonEncode(details) : null,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

