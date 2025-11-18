import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/database_service.dart';
import '../utils/auth_guard.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

// تعريف AuditAction محلياً لتجنب التبعيات الدائرية
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

/// Middleware لتسجيل تلقائي للأحداث المهمة
Middleware auditMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      final user = getRequestUser(request);
      
      // تجاهل طلبات Health Check والطلبات غير المصادق عليها
      if (request.url.path == '/health' || user.role == 'guest') {
        return await handler(request);
      }

      // تحديد نوع الإجراء من المسار
      final action = _determineAction(request);
      if (action == null) {
        return await handler(request);
      }

      // قراءة Body قبل تنفيذ Handler (لأن Stream يمكن قراءته مرة واحدة فقط)
      String? requestBody;
      try {
        requestBody = await request.readAsString();
      } catch (_) {
        // تجاهل الأخطاء
      }

      // إعادة إنشاء Request مع Body
      final modifiedRequest = requestBody != null
          ? request.change(body: requestBody)
          : request;

      // تنفيذ الطلب
      final response = await handler(modifiedRequest);

      // تسجيل الحدث فقط للطلبات الناجحة (2xx)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _logAuditEvent(
          user: user,
          action: action,
          request: request,
          requestBody: requestBody,
        );
      }

      return response;
    };
  };
}

/// تحديد نوع الإجراء من Request
AuditAction? _determineAction(Request request) {
  final path = request.url.path;
  final method = request.method;

  // تسجيل الدخول/الخروج
  if (path.contains('/auth/login') && method == 'POST') {
    return AuditAction.login;
  }
  if (path.contains('/auth/logout') && method == 'POST') {
    return AuditAction.logout;
  }

  // إدارة المستخدمين
  if (path.contains('/users') && method == 'POST') {
    return AuditAction.createUser;
  }
  if (path.contains('/users') && method == 'PUT') {
    return AuditAction.updateUser;
  }
  if (path.contains('/users') && method == 'DELETE') {
    return AuditAction.deleteUser;
  }

  // الوصفات
  if (path.contains('/prescriptions') && method == 'POST') {
    return AuditAction.createPrescription;
  }
  if (path.contains('/prescriptions') && method == 'PUT') {
    return AuditAction.updatePrescription;
  }

  // الطلبات
  if (path.contains('/orders') && method == 'POST') {
    return AuditAction.createOrder;
  }
  if (path.contains('/orders') && method == 'PUT') {
    return AuditAction.updateOrder;
  }

  // الكيانات
  if (path.contains('/entities') && method == 'POST') {
    return AuditAction.createEntity;
  }
  if (path.contains('/entities') && method == 'PUT') {
    return AuditAction.updateEntity;
  }
  if (path.contains('/entities') && method == 'DELETE') {
    return AuditAction.deleteEntity;
  }

  // إعدادات النظام
  if (path.contains('/system-settings') && method == 'PUT') {
    return AuditAction.systemSettingsUpdate;
  }

  return null; // لا تسجيل للأحداث الأخرى
}

/// تسجيل حدث Audit
Future<void> _logAuditEvent({
  required RequestUser user,
  required AuditAction action,
  required Request request,
  String? requestBody,
}) async {
  try {
    final conn = await DatabaseService().connection;
    final uuid = const Uuid();
    
    // استخراج resourceId من المسار أو Body
    final resourceId = _extractResourceId(request);
    final resourceType = _extractResourceType(request.url.path);
    
    // استخراج IP Address
    final ipAddress = request.headers['x-forwarded-for'] ?? 
                     request.headers['x-real-ip'] ?? 
                     'unknown';

    // استخراج التفاصيل من Request Body (إن وجد)
    String? details;
    if (requestBody != null && requestBody.isNotEmpty) {
      try {
        final bodyMap = jsonDecode(requestBody) as Map<String, dynamic>?;
        if (bodyMap != null) {
          // إزالة البيانات الحساسة
          final sanitized = Map<String, dynamic>.from(bodyMap);
          sanitized.remove('password');
          sanitized.remove('passwordHash');
          sanitized.remove('token');
          details = jsonEncode(sanitized);
        }
      } catch (_) {
        // تجاهل الأخطاء في parsing
      }
    }

    await conn.execute(
      '''
      INSERT INTO audit_logs 
      (id, user_id, user_name, action, resource_type, resource_id, details,
       ip_address, created_at)
      VALUES (@id, @userId, @userName, @action, @resourceType, @resourceId, @details,
              @ipAddress, @createdAt)
      ''',
      substitutionValues: {
        'id': uuid.v4(),
        'userId': user.id ?? 'unknown',
        'userName': user.role, // يمكن تحسينه لاحقاً لجلب الاسم من DB
        'action': action.toString().split('.').last,
        'resourceType': resourceType,
        'resourceId': resourceId,
        'details': details,
        'ipAddress': ipAddress,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
  } catch (e) {
    // لا نريد أن يفشل الطلب بسبب فشل تسجيل Audit Log
    print('Failed to log audit event: $e');
  }
}

String _extractResourceId(Request request) {
  final path = request.url.path;
  final segments = path.split('/');
  
  // محاولة استخراج ID من المسار (مثل /users/123)
  for (int i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'users' || 
        segments[i] == 'prescriptions' || 
        segments[i] == 'orders' ||
        segments[i] == 'entities') {
      return segments[i + 1];
    }
  }
  
  return 'unknown';
}

String _extractResourceType(String path) {
  if (path.contains('/users')) return 'user';
  if (path.contains('/prescriptions')) return 'prescription';
  if (path.contains('/orders')) return 'order';
  if (path.contains('/entities')) return 'entity';
  if (path.contains('/system-settings')) return 'system_settings';
  return 'unknown';
}

