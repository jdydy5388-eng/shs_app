enum AuditAction {
  login,
  logout,
  createUser,
  updateUser,
  deleteUser,
  createPrescription,
  updatePrescription,
  createOrder,
  updateOrder,
  createEntity,
  updateEntity,
  deleteEntity,
  systemSettingsUpdate,
  viewSensitiveData,
  exportData,
  deleteSensitiveData,
  accessAdminPanel,
  modifyPermissions,
  viewAuditLogs,
  createBackup,
  restoreBackup,
  createEmergencyCase,
  updateEmergencyCase,
  createSurgery,
  updateSurgery,
  createLabRequest,
  updateLabRequest,
  updateLabResult,
  createRadiologyRequest,
  updateRadiologyRequest,
  createInvoice,
  updateInvoice,
  deleteInvoice,
  createPayment,
  generateReport,
  viewFinancialReports,
  createEmployee,
  updateEmployee,
  deleteEmployee,
  createPayroll,
  updatePayroll,
  createIncident,
  updateIncident,
  createComplaint,
  updateComplaint,
  createMaintenanceRequest,
  updateMaintenanceRequest,
  createTransportationRequest,
  updateTransportationRequest,
  createIntegration,
  syncIntegration,
}

class AuditLogModel {
  const AuditLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.timestamp,
    this.details,
    this.ipAddress,
  });

  final String id;
  final String userId;
  final String userName;
  final AuditAction action;
  final String resourceType;
  final String resourceId;
  final DateTime timestamp;
  final String? details;
  final String? ipAddress;

  String get actionName {
    switch (action) {
      case AuditAction.login:
        return 'تسجيل دخول';
      case AuditAction.logout:
        return 'تسجيل خروج';
      case AuditAction.createUser:
        return 'إنشاء مستخدم';
      case AuditAction.updateUser:
        return 'تحديث مستخدم';
      case AuditAction.deleteUser:
        return 'حذف مستخدم';
      case AuditAction.createPrescription:
        return 'إنشاء وصفة';
      case AuditAction.updatePrescription:
        return 'تحديث وصفة';
      case AuditAction.createOrder:
        return 'إنشاء طلب';
      case AuditAction.updateOrder:
        return 'تحديث طلب';
      case AuditAction.createEntity:
        return 'إنشاء كيان';
      case AuditAction.updateEntity:
        return 'تحديث كيان';
      case AuditAction.deleteEntity:
        return 'حذف كيان';
      case AuditAction.systemSettingsUpdate:
        return 'تحديث إعدادات النظام';
      case AuditAction.viewSensitiveData:
        return 'عرض بيانات حساسة';
      case AuditAction.exportData:
        return 'تصدير بيانات';
      case AuditAction.deleteSensitiveData:
        return 'حذف بيانات حساسة';
      case AuditAction.accessAdminPanel:
        return 'الوصول إلى لوحة الإدارة';
      case AuditAction.modifyPermissions:
        return 'تعديل الصلاحيات';
      case AuditAction.viewAuditLogs:
        return 'عرض سجلات التدقيق';
      case AuditAction.createBackup:
        return 'إنشاء نسخة احتياطية';
      case AuditAction.restoreBackup:
        return 'استعادة نسخة احتياطية';
      case AuditAction.createEmergencyCase:
        return 'إنشاء حالة طوارئ';
      case AuditAction.updateEmergencyCase:
        return 'تحديث حالة طوارئ';
      case AuditAction.createSurgery:
        return 'إنشاء عملية جراحية';
      case AuditAction.updateSurgery:
        return 'تحديث عملية جراحية';
      case AuditAction.createLabRequest:
        return 'إنشاء طلب مختبر';
      case AuditAction.updateLabRequest:
        return 'تحديث طلب مختبر';
      case AuditAction.updateLabResult:
        return 'تحديث نتيجة مختبر';
      case AuditAction.createRadiologyRequest:
        return 'إنشاء طلب أشعة';
      case AuditAction.updateRadiologyRequest:
        return 'تحديث طلب أشعة';
      case AuditAction.createInvoice:
        return 'إنشاء فاتورة';
      case AuditAction.updateInvoice:
        return 'تحديث فاتورة';
      case AuditAction.deleteInvoice:
        return 'حذف فاتورة';
      case AuditAction.createPayment:
        return 'إنشاء دفعة';
      case AuditAction.generateReport:
        return 'إنشاء تقرير';
      case AuditAction.viewFinancialReports:
        return 'عرض التقارير المالية';
      case AuditAction.createEmployee:
        return 'إنشاء موظف';
      case AuditAction.updateEmployee:
        return 'تحديث موظف';
      case AuditAction.deleteEmployee:
        return 'حذف موظف';
      case AuditAction.createPayroll:
        return 'إنشاء راتب';
      case AuditAction.updatePayroll:
        return 'تحديث راتب';
      case AuditAction.createIncident:
        return 'إنشاء حادث طبي';
      case AuditAction.updateIncident:
        return 'تحديث حادث طبي';
      case AuditAction.createComplaint:
        return 'إنشاء شكوى';
      case AuditAction.updateComplaint:
        return 'تحديث شكوى';
      case AuditAction.createMaintenanceRequest:
        return 'إنشاء طلب صيانة';
      case AuditAction.updateMaintenanceRequest:
        return 'تحديث طلب صيانة';
      case AuditAction.createTransportationRequest:
        return 'إنشاء طلب نقل';
      case AuditAction.updateTransportationRequest:
        return 'تحديث طلب نقل';
      case AuditAction.createIntegration:
        return 'إنشاء تكامل';
      case AuditAction.syncIntegration:
        return 'مزامنة تكامل';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'action': action.toString().split('.').last,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'details': details,
      'ip_address': ipAddress,
    };
  }

  factory AuditLogModel.fromMap(Map<String, dynamic> map) {
    return AuditLogModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      action: AuditAction.values.firstWhere(
        (e) => e.toString().split('.').last == map['action'],
        orElse: () => AuditAction.login,
      ),
      resourceType: map['resource_type'] as String,
      resourceId: map['resource_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      details: map['details'] as String?,
      ipAddress: map['ip_address'] as String?,
    );
  }
}

