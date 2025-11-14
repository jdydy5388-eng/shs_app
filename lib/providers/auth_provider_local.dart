import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/local_auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/data_service.dart';
import '../config/app_config.dart';
import 'dart:convert';
import 'dart:async';

/// Provider للمصادقة - يدعم الوضع المحلي والشبكي
class AuthProviderLocal with ChangeNotifier {
  final LocalAuthService _localAuthService = LocalAuthService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  final DataService _dataService = DataService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProviderLocal() {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await _localAuthService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      if (AppConfig.isNetworkMode) {
        // الوضع الشبكي - استخدام الخادم
        final response = await _dataService.loginUser(
          email: email,
          password: password,
        );
        
        if (response.containsKey('user')) {
          final userMap = response['user'] as Map<String, dynamic>;
          // تحويل camelCase إلى التنسيق المتوقع
          // معالجة additionalInfo - قد يكون JSON string أو Map
          dynamic additionalInfo = userMap['additionalInfo'];
          if (additionalInfo is String) {
            try {
              additionalInfo = jsonDecode(additionalInfo);
            } catch (_) {
              additionalInfo = null;
            }
          }
          
          final convertedMap = <String, dynamic>{
            'id': userMap['id'],
            'name': userMap['name'],
            'email': userMap['email'],
            'phone': userMap['phone'],
            'role': userMap['role'],
            'profileImageUrl': userMap['profileImageUrl'],
            'additionalInfo': additionalInfo,
            'createdAt': userMap['createdAt'],
            'lastLoginAt': userMap['lastLoginAt'],
          };
          final user = UserModel.fromMap(convertedMap, convertedMap['id'] as String);
          
          // حفظ محلياً للمصادقة البيومترية
          await _localAuthService.saveUser(user);
          await _localAuthService.setCurrentUser(user.id);
          
          // حفظ كلمة المرور محلياً (للمصادقة البيومترية)
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_password_${user.id}', password);
          
          _currentUser = user;
          notifyListeners();
          return true;
        } else {
          _errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
          return false;
        }
      } else {
        // الوضع المحلي - استخدام SharedPreferences
        final success = await _localAuthService.signInWithEmailAndPassword(
          email,
          password,
        );

        if (success) {
          await _loadCurrentUser();
          return true;
        } else {
          _errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
          return false;
        }
      }
    } catch (e) {
      _errorMessage = _mapLoginErrorToMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithBiometric() async {
    _setLoading(true);
    _errorMessage = null;
    
    try {
      // التحقق من دعم الجهاز فقط (بدون التحقق من إعدادات النظام)
      final isAvailable = await _biometricAuthService.isBiometricAvailable();
      if (!isAvailable) {
        _errorMessage = 'المصادقة البيومترية غير متاحة على هذا الجهاز';
        return false;
      }

      // الحصول على معرف المستخدم المرتبط بالبصمة
      final biometricUserId = await _localAuthService.getBiometricUserId();
      if (biometricUserId == null) {
        _errorMessage = 'لا يوجد مستخدم مسجل للبصمة. يرجى تفعيل المصادقة البيومترية أولاً';
        return false;
      }

      // التحقق من أن المستخدم لديه بصمة مفعلة
      final isUserEnabled = await _localAuthService.isUserBiometricEnabled(biometricUserId);
      if (!isUserEnabled) {
        _errorMessage = 'المصادقة البيومترية غير مفعلة لهذا المستخدم';
        return false;
      }

      // طلب المصادقة البيومترية
      final authenticated = await _biometricAuthService.authenticate(
        localizedReason: 'يرجى المصادقة للوصول إلى حسابك',
      );

      if (authenticated) {
        // تسجيل دخول المستخدم المرتبط بالبصمة من التخزين المحلي
        final user = await _localAuthService.getUserById(biometricUserId);
        if (user == null) {
          _errorMessage = 'المستخدم غير موجود. يرجى إعادة تسجيل الدخول باستخدام البريد وكلمة المرور.';
          return false;
        }

        await _localAuthService.setCurrentUser(user.id);
        _currentUser = user;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'فشلت المصادقة البيومترية';
        return false;
      }
    } catch (e) {
      _errorMessage = 'خطأ في المصادقة البيومترية: ${e.toString()}';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
    Map<String, dynamic>? additionalInfo,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      if (AppConfig.isNetworkMode) {
        // الوضع الشبكي - استخدام الخادم
        try {
          final response = await _dataService.registerUser(
            email: email,
            password: password,
            name: name,
            phone: phone,
            role: role.toString().split('.').last,
            additionalInfo: additionalInfo,
          );
          
          // بعد التسجيل الناجح، تسجيل الدخول تلقائياً
          final loginResponse = await _dataService.loginUser(
            email: email,
            password: password,
          );
          
          if (loginResponse.containsKey('user')) {
            final userMap = loginResponse['user'] as Map<String, dynamic>;
            // تحويل camelCase إلى التنسيق المتوقع
            final convertedMap = <String, dynamic>{
              'id': userMap['id'],
              'name': userMap['name'],
              'email': userMap['email'],
              'phone': userMap['phone'],
              'role': userMap['role'],
              'profileImageUrl': userMap['profileImageUrl'],
              'additionalInfo': userMap['additionalInfo'],
              'createdAt': userMap['createdAt'],
              'lastLoginAt': userMap['lastLoginAt'],
            };
            final user = UserModel.fromMap(convertedMap, convertedMap['id'] as String);
            
            // حفظ محلياً للمصادقة البيومترية
            await _localAuthService.saveUser(user);
            await _localAuthService.setCurrentUser(user.id);
            
            // حفظ كلمة المرور محلياً (للمصادقة البيومترية)
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_password_${user.id}', password);
            
            _currentUser = user;
            notifyListeners();
            return true;
          } else {
            _errorMessage = 'تم إنشاء الحساب لكن فشل تسجيل الدخول';
            return false;
          }
        } catch (e) {
          // التحقق من نوع الخطأ
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('already exists') || errorStr.contains('email')) {
            _errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
          } else {
            _errorMessage = 'خطأ في إنشاء الحساب: ${e.toString()}';
          }
          return false;
        }
      } else {
        // الوضع المحلي - استخدام SharedPreferences
        // التحقق من عدم وجود مستخدم بنفس البريد
        final existingUser = await _localAuthService.getUserByEmail(email);
        if (existingUser != null) {
          _errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
          return false;
        }

        await _localAuthService.createUserWithEmailAndPassword(
          email: email,
          password: password,
          name: name,
          phone: phone,
          role: role,
          additionalInfo: additionalInfo,
        );

        await _loadCurrentUser();
        return true;
      }
    } catch (e) {
      _errorMessage = 'خطأ في إنشاء الحساب: ${e.toString()}';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _localAuthService.signOut();
      _currentUser = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'خطأ في تسجيل الخروج: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> updateCurrentUser(UserModel user) async {
    await _localAuthService.updateUser(user);
    _currentUser = user;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapLoginErrorToMessage(Object e) {
    final error = e.toString();
    final lower = error.toLowerCase();
    
    // التحقق من أنواع الأخطاء عبر النص (متوافق مع الويب)
    if (e is TimeoutException) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.';
    }
    if (lower.contains('socket') || lower.contains('connection') || lower.contains('network')) {
      return 'تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت أو إعدادات الخادم.';
    }

    if (lower.contains('http 401') || lower.contains('invalid email or password')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (lower.contains('http 403')) {
      return 'لا تملك صلاحية الوصول. يرجى التواصل مع المسؤول.';
    }
    if (lower.contains('http 404')) {
      return 'واجهة تسجيل الدخول غير متاحة. تحقق من عنوان الخادم.';
    }
    if (lower.contains('http 500') || lower.contains('login failed')) {
      return 'حدث خطأ في الخادم أثناء تسجيل الدخول. حاول لاحقاً.';
    }
    if (lower.contains('failed host lookup') || lower.contains('connection refused') || lower.contains('timed out')) {
      return 'تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت أو إعدادات الخادم.';
    }

    return 'تعذّر تسجيل الدخول. يرجى المحاولة مرة أخرى.';
  }
}

