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

