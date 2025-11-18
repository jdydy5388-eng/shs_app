import 'package:shelf/shelf.dart';
import 'rbac.dart';

class RequestUser {
  final String? id;
  final String role; // admin/doctor/patient/pharmacist
  const RequestUser(this.id, this.role);

  bool get isAdmin => role == 'admin';
  bool get isDoctor => role == 'doctor';
  bool get isPatient => role == 'patient';
  bool get isPharmacist => role == 'pharmacist';
}

RequestUser getRequestUser(Request request) {
  final headers = request.headers;
  final id = headers['x-user-id'];
  final role = (headers['x-user-role'] ?? '').toLowerCase();
  if (role.isEmpty) return const RequestUser(null, 'guest');
  return RequestUser(id, role);
}

bool canAccessPatientData(RequestUser user, String? patientId) {
  if (user.isAdmin) return true;
  if (user.isPatient && user.id != null && patientId != null && user.id == patientId) return true;
  if (user.isDoctor) return true; // يمكن تضييقها لاحقاً حسب علاقة الطبيب بالمريض
  if (user.isPharmacist) return false;
  return false;
}

bool canAccessDoctorData(RequestUser user, String? doctorId) {
  if (user.isAdmin) return true;
  if (user.isDoctor && user.id != null && doctorId != null && user.id == doctorId) return true;
  return false;
}

bool isAuthenticated(RequestUser user) => user.role != 'guest';

/// Middleware للتحقق من المصادقة
Middleware requireAuth() {
  return (Handler handler) {
    return (Request request) async {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) {
        return Response(
          401,
          body: '{"error": "Unauthorized. Please login first."}',
          headers: {'Content-Type': 'application/json'},
        );
      }
      return await handler(request);
    };
  };
}

/// Middleware للتحقق من الصلاحيات
Middleware requirePermission(Permission permission) {
  return (Handler handler) {
    return (Request request) async {
      final user = getRequestUser(request);
      if (!isAuthenticated(user)) {
        return Response(
          401,
          body: '{"error": "Unauthorized. Please login first."}',
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      // التحقق من الصلاحية
      final hasPermission = Rbac.has(user.role, permission);
      if (!hasPermission) {
        return Response(
          403,
          body: '{"error": "Forbidden. You do not have permission to perform this action."}',
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      return await handler(request);
    };
  };
}


