import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../handlers/auth_handler.dart';
import '../handlers/users_handler.dart';
import '../handlers/prescriptions_handler.dart';
import '../handlers/orders_handler.dart';
import '../handlers/appointments_handler.dart';
import '../handlers/medical_records_handler.dart';
import '../handlers/inventory_handler.dart';
import '../handlers/lab_requests_handler.dart';
import '../handlers/entities_handler.dart';
import '../handlers/audit_logs_handler.dart';
import '../handlers/system_settings_handler.dart';
import '../handlers/billing_handler.dart';
import '../handlers/rooms_handler.dart';
import '../handlers/emergency_handler.dart';
import '../handlers/notifications_handler.dart';
import '../handlers/radiology_handler.dart';
import '../handlers/attendance_handler.dart';
import '../handlers/storage_handler.dart';

class ApiRoutes {
  static Router createRouter() {
    final router = Router();

    // Health check
    router.get('/health', (Request request) {
      return Response.ok('Server is running');
    });

    // API Routes
    router.mount('/api/auth', AuthHandler().router);
    router.mount('/api/users', UsersHandler().router);
    router.mount('/api/prescriptions', PrescriptionsHandler().router);
    router.mount('/api/orders', OrdersHandler().router);
    router.mount('/api/appointments', AppointmentsHandler().router);
    router.mount('/api/medical-records', MedicalRecordsHandler().router);
    router.mount('/api/inventory', InventoryHandler().router);
    router.mount('/api/lab-requests', LabRequestsHandler().router);
    router.mount('/api/entities', EntitiesHandler().router);
    router.mount('/api/audit-logs', AuditLogsHandler().router);
    router.mount('/api/system-settings', SystemSettingsHandler().router);
    router.mount('/api/billing', BillingHandler().router);
    router.mount('/api/rooms', RoomsHandler().router);
    router.mount('/api/emergency', EmergencyHandler().router);
    router.mount('/api/notifications', NotificationsHandler().router);
    router.mount('/api/radiology', RadiologyHandler().router);
    router.mount('/api/attendance', AttendanceHandler().router);
    router.mount('/api/storage', StorageHandler().router);

    // 404 handler
    router.all('/<path|.*>', (Request request) {
      return Response.notFound('Route not found: ${request.url.path}');
    });

    return router;
  }
}

