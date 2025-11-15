import '../models/user_model.dart';

class NetworkAuthContext {
  static String? _userId;
  static String? _role; // patient/doctor/pharmacist/admin

  static Map<String, String> headers() {
    final headers = <String, String>{};
    if (_userId != null && _userId!.isNotEmpty) {
      headers['x-user-id'] = _userId!;
    }
    if (_role != null && _role!.isNotEmpty) {
      headers['x-user-role'] = _role!;
    }
    return headers;
  }

  static void setUser(UserModel? user) {
    if (user == null) {
      _userId = null;
      _role = null;
      return;
    }
    _userId = user.id;
    _role = user.role.toString().split('.').last;
  }
}


