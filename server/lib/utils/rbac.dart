enum Permission {
  // Radiology
  readRadiology,
  writeRadiology,
  
  // Attendance
  readAttendance,
  writeAttendance,
  manageShifts,
  
  // Storage
  readStorage,
  writeStorage,
  
  // Users Management
  readUsers,
  createUsers,
  updateUsers,
  deleteUsers,
  
  // Prescriptions
  readPrescriptions,
  createPrescriptions,
  updatePrescriptions,
  
  // Orders
  readOrders,
  createOrders,
  updateOrders,
  
  // Medical Records
  readMedicalRecords,
  createMedicalRecords,
  updateMedicalRecords,
  
  // Appointments
  readAppointments,
  createAppointments,
  updateAppointments,
  
  // Emergency
  readEmergency,
  createEmergency,
  updateEmergency,
  
  // Rooms & Beds
  readRooms,
  manageRooms,
  
  // System
  viewAuditLogs,
  manageSystemSettings,
}

class Rbac {
  static final Map<String, Set<Permission>> _rolePermissions = {
    'admin': {
      // جميع الصلاحيات
      Permission.readRadiology,
      Permission.writeRadiology,
      Permission.readAttendance,
      Permission.writeAttendance,
      Permission.manageShifts,
      Permission.readStorage,
      Permission.writeStorage,
      Permission.readUsers,
      Permission.createUsers,
      Permission.updateUsers,
      Permission.deleteUsers,
      Permission.readPrescriptions,
      Permission.createPrescriptions,
      Permission.updatePrescriptions,
      Permission.readOrders,
      Permission.createOrders,
      Permission.updateOrders,
      Permission.readMedicalRecords,
      Permission.createMedicalRecords,
      Permission.updateMedicalRecords,
      Permission.readAppointments,
      Permission.createAppointments,
      Permission.updateAppointments,
      Permission.readEmergency,
      Permission.createEmergency,
      Permission.updateEmergency,
      Permission.readRooms,
      Permission.manageRooms,
      Permission.viewAuditLogs,
      Permission.manageSystemSettings,
    },
    'doctor': {
      Permission.readRadiology,
      Permission.writeRadiology,
      Permission.readStorage,
      Permission.writeStorage,
      Permission.readUsers, // قراءة بيانات المرضى
      Permission.readPrescriptions,
      Permission.createPrescriptions,
      Permission.updatePrescriptions,
      Permission.readMedicalRecords,
      Permission.createMedicalRecords,
      Permission.updateMedicalRecords,
      Permission.readAppointments,
      Permission.createAppointments,
      Permission.updateAppointments,
      Permission.readEmergency,
      Permission.createEmergency,
      Permission.updateEmergency,
      Permission.readRooms,
    },
    'patient': {
      Permission.readRadiology,
      Permission.readStorage,
      Permission.readPrescriptions, // قراءة وصفاته فقط
      Permission.readMedicalRecords, // قراءة سجله فقط
      Permission.readAppointments, // قراءة مواعيده فقط
      Permission.createAppointments, // حجز مواعيد
      Permission.readOrders, // قراءة طلباته
      Permission.createOrders, // إنشاء طلبات
    },
    'pharmacist': {
      Permission.readStorage,
      Permission.writeStorage,
      Permission.readOrders,
      Permission.updateOrders, // تحديث حالة الطلبات
      Permission.readPrescriptions, // قراءة الوصفات للطلبات
    },
    'labTechnician': {
      Permission.readStorage,
      Permission.writeStorage,
      Permission.readMedicalRecords, // قراءة طلبات الفحوصات
      Permission.updateMedicalRecords, // تحديث نتائج الفحوصات
    },
    'radiologist': {
      Permission.readRadiology,
      Permission.writeRadiology,
      Permission.readStorage,
      Permission.writeStorage,
    },
  };

  static bool has(String role, Permission permission) {
    final perms = _rolePermissions[role] ?? {};
    return perms.contains(permission);
  }

  /// التحقق من صلاحيات متعددة (AND)
  static bool hasAll(String role, Set<Permission> permissions) {
    final perms = _rolePermissions[role] ?? {};
    return permissions.every((p) => perms.contains(p));
  }

  /// التحقق من صلاحيات متعددة (OR)
  static bool hasAny(String role, Set<Permission> permissions) {
    final perms = _rolePermissions[role] ?? {};
    return permissions.any((p) => perms.contains(p));
  }

  /// الحصول على جميع صلاحيات دور معين
  static Set<Permission> getPermissions(String role) {
    return _rolePermissions[role] ?? {};
  }
}


