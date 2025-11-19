import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/audit_log_model.dart';
import '../services/data_service.dart';
import '../utils/auth_helper.dart';
import 'encryption_service.dart';

/// خدمة تسجيل العمليات الحساسة المحسنة
class EnhancedAuditService {
  static final EnhancedAuditService _instance = EnhancedAuditService._internal();
  factory EnhancedAuditService() => _instance;
  EnhancedAuditService._internal();

  final DataService _dataService = DataService();
  final EncryptionService _encryptionService = EncryptionService();
  final Uuid _uuid = const Uuid();

  /// تسجيل عملية حساسة
  Future<void> logSensitiveAction({
    required AuditAction action,
    required String resourceType,
    required String resourceId,
    Map<String, dynamic>? details,
    String? userId,
    String? userName,
  }) async {
    try {
      // الحصول على معلومات المستخدم الحالي
      final currentUserId = userId ?? 'system';
      final currentUserName = userName ?? 'System';

      // الحصول على عنوان IP (إن أمكن)
      String? ipAddress;
      try {
        // TODO: الحصول على IP الحقيقي من الطلب
        ipAddress = '127.0.0.1';
      } catch (e) {
        // تجاهل الخطأ
      }

      // تشفير التفاصيل الحساسة إن وجدت
      Map<String, dynamic>? encryptedDetails;
      if (details != null) {
        try {
          await _encryptionService.initialize();
          encryptedDetails = _encryptionService.encryptMap(details);
        } catch (e) {
          // في حالة فشل التشفير، حفظ بدون تشفير
          encryptedDetails = details;
        }
      }

      final auditLog = AuditLogModel(
        id: _uuid.v4(),
        userId: currentUserId,
        userName: currentUserName,
        action: action,
        resourceType: resourceType,
        resourceId: resourceId,
        timestamp: DateTime.now(),
        details: encryptedDetails != null ? encryptedDetails.toString() : null,
        ipAddress: ipAddress,
      );

      await _dataService.createAuditLog(auditLog);
    } catch (e) {
      // لا نريد أن يفشل التطبيق بسبب فشل التسجيل
      // يمكن إضافة logging هنا
      print('Failed to log audit: $e');
    }
  }

  /// تسجيل محاولة وصول غير مصرح
  Future<void> logUnauthorizedAccess({
    required String resourceType,
    required String resourceId,
    String? attemptedAction,
  }) async {
    await logSensitiveAction(
      action: AuditAction.viewSensitiveData,
      resourceType: resourceType,
      resourceId: resourceId,
      details: {
        'unauthorized': true,
        'attemptedAction': attemptedAction,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// تسجيل تصدير بيانات
  Future<void> logDataExport({
    required String dataType,
    required int recordCount,
    Map<String, dynamic>? filters,
  }) async {
    await logSensitiveAction(
      action: AuditAction.exportData,
      resourceType: dataType,
      resourceId: 'export_${DateTime.now().millisecondsSinceEpoch}',
      details: {
        'dataType': dataType,
        'recordCount': recordCount,
        'filters': filters,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// تسجيل حذف بيانات حساسة
  Future<void> logSensitiveDataDeletion({
    required String resourceType,
    required String resourceId,
    Map<String, dynamic>? deletedData,
  }) async {
    await logSensitiveAction(
      action: AuditAction.deleteSensitiveData,
      resourceType: resourceType,
      resourceId: resourceId,
      details: {
        'deletedData': deletedData,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// تسجيل تعديل الصلاحيات
  Future<void> logPermissionChange({
    required String targetUserId,
    required String targetUserRole,
    required Map<String, dynamic> permissionChanges,
  }) async {
    await logSensitiveAction(
      action: AuditAction.modifyPermissions,
      resourceType: 'user',
      resourceId: targetUserId,
      details: {
        'targetUserRole': targetUserRole,
        'permissionChanges': permissionChanges,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// تسجيل إنشاء/استعادة نسخة احتياطية
  Future<void> logBackupOperation({
    required bool isRestore,
    required String backupPath,
    bool success = true,
    String? errorMessage,
  }) async {
    await logSensitiveAction(
      action: isRestore ? AuditAction.restoreBackup : AuditAction.createBackup,
      resourceType: 'backup',
      resourceId: backupPath,
      details: {
        'backupPath': backupPath,
        'success': success,
        'errorMessage': errorMessage,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}

