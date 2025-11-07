import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class BiometricAuthService {
  LocalAuthentication? _localAuth;
  
  BiometricAuthService() {
    // تهيئة local_auth فقط على المنصات المدعومة
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _localAuth = LocalAuthentication();
    }
  }

  Future<bool> isBiometricAvailable() async {
    // Windows و Linux لا يدعمان المصادقة البيومترية
    if (Platform.isWindows || Platform.isLinux) {
      return false;
    }
    
    if (_localAuth == null) {
      return false;
    }
    
    try {
      // التحقق من دعم الجهاز أولاً
      final bool isDeviceSupported = await _localAuth!.isDeviceSupported();
      
      if (!isDeviceSupported) {
        return false;
      }
      
      // الحصول على أنواع البصمة المتاحة (هذا يطلب الصلاحيات تلقائياً)
      try {
        final List<BiometricType> availableBiometrics = await _localAuth!.getAvailableBiometrics();
        
        // إذا كان هناك أنواع بصمة متاحة، فالجهاز يدعمها
        if (availableBiometrics.isNotEmpty) {
          return true;
        }
      } on PlatformException catch (e) {
        // على Android، NotEnrolled يعني أن البصمة متاحة لكن غير مسجلة
        if (e.code == 'NotEnrolled') {
          // الجهاز يدعم البصمة لكن المستخدم لم يسجلها بعد
          return true; // نعيد true لأن الجهاز يدعمها
        }
        // لأخطاء أخرى، نعيد false
        return false;
      }
      
      // التحقق من canCheckBiometrics كحل بديل
      try {
        final bool canCheckBiometrics = await _localAuth!.canCheckBiometrics;
        
        // إذا كان الجهاز مدعوم ويمكن التحقق، نعيد true
        if (canCheckBiometrics && isDeviceSupported) {
          return true;
        }
      } catch (e) {
        // تجاهل الخطأ
      }
      
      return false;
    } on PlatformException catch (e) {
      // معالجة حالات مختلفة
      if (e.code == 'NotEnrolled') {
        // الجهاز يدعم البصمة لكن غير مسجلة
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (Platform.isWindows || Platform.isLinux || _localAuth == null) {
      return [];
    }
    
    try {
      final biometrics = await _localAuth!.getAvailableBiometrics();
      return biometrics;
    } on PlatformException catch (e) {
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> checkBiometricStatus() async {
    if (Platform.isWindows || Platform.isLinux || _localAuth == null) {
      return {
        'supported': false,
        'enrolled': false,
        'available': false,
        'message': 'المنصة لا تدعم المصادقة البيومترية',
      };
    }
    
    try {
      final bool isDeviceSupported = await _localAuth!.isDeviceSupported();
      
      if (!isDeviceSupported) {
        return {
          'supported': false,
          'enrolled': false,
          'available': false,
          'message': 'الجهاز لا يدعم المصادقة البيومترية',
        };
      }
      
      try {
        final List<BiometricType> availableBiometrics = await _localAuth!.getAvailableBiometrics();
        
        if (availableBiometrics.isNotEmpty) {
          return {
            'supported': true,
            'enrolled': true,
            'available': true,
            'types': availableBiometrics,
            'message': 'البصمة متاحة ومسجلة',
          };
        } else {
          return {
            'supported': true,
            'enrolled': false,
            'available': false,
            'message': 'الجهاز يدعم البصمة لكن لا توجد بصمات مسجلة',
          };
        }
      } on PlatformException catch (e) {
        if (e.code == 'NotEnrolled') {
          return {
            'supported': true,
            'enrolled': false,
            'available': false,
            'error': e.code,
            'message': 'الجهاز يدعم البصمة لكن لا توجد بصمات مسجلة في إعدادات الجهاز',
          };
        } else if (e.code == 'PasscodeNotSet') {
          return {
            'supported': true,
            'enrolled': false,
            'available': false,
            'error': e.code,
            'message': 'قفل الشاشة غير مفعل. يجب تفعيل PIN/Pattern/Password أولاً',
          };
        }
        
        return {
          'supported': true,
          'enrolled': false,
          'available': false,
          'error': e.code,
          'message': 'خطأ: ${e.message}',
        };
      }
    } catch (e) {
      return {
        'supported': false,
        'enrolled': false,
        'available': false,
        'message': 'خطأ في التحقق: $e',
      };
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'يرجى المصادقة للوصول إلى التطبيق',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    // Windows و Linux لا يدعمان المصادقة البيومترية
    if (Platform.isWindows || Platform.isLinux) {
      return false;
    }
    
    if (_localAuth == null) return false;
    
    try {
      final bool didAuthenticate = await _localAuth!.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: false, // يسمح بالبصمة والوجه
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('خطأ في المصادقة البيومترية: ${e.message}');
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> stopAuthentication() async {
    if (Platform.isWindows || Platform.isLinux || _localAuth == null) {
      return false;
    }
    
    try {
      return await _localAuth!.stopAuthentication();
    } catch (e) {
      return false;
    }
  }
}

