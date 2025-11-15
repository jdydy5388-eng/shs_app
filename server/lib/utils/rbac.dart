enum Permission {
  readRadiology,
  writeRadiology,
  readAttendance,
  writeAttendance,
  manageShifts,
  readStorage,
  writeStorage,
}

class Rbac {
  static final Map<String, Set<Permission>> _rolePermissions = {
    'admin': {
      Permission.readRadiology,
      Permission.writeRadiology,
      Permission.readAttendance,
      Permission.writeAttendance,
      Permission.manageShifts,
      Permission.readStorage,
      Permission.writeStorage,
    },
    'doctor': {
      Permission.readRadiology,
      Permission.writeRadiology,
      Permission.readStorage,
      Permission.writeStorage,
    },
    'patient': {
      Permission.readRadiology,
      Permission.readStorage,
    },
    'pharmacist': {
      Permission.readStorage,
    },
  };

  static bool has(String role, Permission permission) {
    final perms = _rolePermissions[role] ?? {};
    return perms.contains(permission);
  }
}


