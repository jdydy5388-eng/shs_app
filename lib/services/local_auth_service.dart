import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// خدمة المصادقة المحلية (بدون Firebase)
class LocalAuthService {
  static const String _usersKey = 'local_users';
  static const String _currentUserKey = 'current_user_id';

  // تخزين المستخدمين محلياً
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList(_usersKey) ?? [];
    
    // التحقق من وجود المستخدم
    final existingIndex = usersJson.indexWhere((json) {
      final map = jsonDecode(json);
      return map['id'] == user.id || map['email'] == user.email;
    });

    final userJson = jsonEncode(user.toMap());
    
    if (existingIndex >= 0) {
      usersJson[existingIndex] = userJson;
    } else {
      usersJson.add(userJson);
    }

    await prefs.setStringList(_usersKey, usersJson);
  }

  Future<UserModel?> getUserById(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList(_usersKey) ?? [];

    for (final json in usersJson) {
      final map = jsonDecode(json);
      if (map['id'] == userId) {
        return UserModel.fromMap(map, userId);
      }
    }
    return null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getStringList(_usersKey) ?? [];

    for (final json in usersJson) {
      final map = jsonDecode(json);
      if (map['email'] == email) {
        return UserModel.fromMap(map, map['id']);
      }
    }
    return null;
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user == null) return false;

    // في الوضع المحلي، نتحقق من كلمة المرور
    // هنا يمكن إضافة hash لكلمة المرور
    final prefs = await SharedPreferences.getInstance();
    final passwordKey = 'user_password_${user.id}';
    final savedPassword = prefs.getString(passwordKey);

    if (savedPassword == password) {
      await setCurrentUser(user.id);
      return true;
    }

    return false;
  }

  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    Map<String, dynamic>? additionalInfo,
  }) async {
    final userId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final user = UserModel(
      id: userId,
      name: name,
      email: email,
      phone: phone,
      role: role,
      additionalInfo: additionalInfo,
      createdAt: DateTime.now(),
    );

    await saveUser(user);
    
    // حفظ كلمة المرور (في الإنتاج يجب hash)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_password_$userId', password);

    await setCurrentUser(userId);
    return userId;
  }

  Future<void> setCurrentUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, userId);
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  Future<UserModel?> getCurrentUser() async {
    final userId = await getCurrentUserId();
    if (userId == null) return null;
    return getUserById(userId);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // Biometric settings for users
  Future<void> setUserBiometricEnabled(String userId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled_$userId', enabled);
    if (enabled) {
      // حفظ معرف المستخدم المرتبط بالبصمة
      await prefs.setString('biometric_user_id', userId);
    } else {
      // حذف المعرف إذا تم تعطيل البصمة
      final savedUserId = prefs.getString('biometric_user_id');
      if (savedUserId == userId) {
        await prefs.remove('biometric_user_id');
      }
    }
  }

  Future<bool> isUserBiometricEnabled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled_$userId') ?? false;
  }

  Future<String?> getBiometricUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('biometric_user_id');
  }

  Future<void> updateUser(UserModel user) async {
    await saveUser(user);
  }
}

