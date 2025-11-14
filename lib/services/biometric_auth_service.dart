import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:io' show Platform;

class BiometricAuthService {
  LocalAuthentication? _localAuth;
  
  BiometricAuthService() {
    // على الويب، لا يمكننا استخدام المصادقة البيومترية
    if (kIsWeb) {
      return;
    }
    
    // تهيئة local_auth فقط على المنصات المدعومة
    try {
      if (!kIsWeb) {
        // ignore: undefined_class, undefined_getter
        final isMobile = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
        if (isMobile) {
          _localAuth = LocalAuthentication();
        }
      }
    } catch (e) {
      // تجاهل الخطأ إذا كان Platform غير متاح
    }
  }

  Future<bool> isBiometricAvailable() async {
    // على الويب، لا يمكننا استخدام المصادقة البيومترية
    if (kIsWeb) {
      return false;
    }
    
    // Windows و Linux لا يدعمان المصادقة البيومترية
    if (!kIsWeb) {
      try {
        // ignore: undefined_class, undefined_getter
        final isDesktop = Platform.isWindows || Platform.isLinux;
        if (isDesktop) {
          return false;
        }
      } catch (e) {
        return false;
      }
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
    if (kIsWeb || _localAuth == null) {
      return [];
    }
    
    if (!kIsWeb) {
      try {
        // ignore: undefined_class, undefined_getter
        final isDesktop = Platform.isWindows || Platform.isLinux;
        if (isDesktop) {
          return [];
        }
      } catch (e) {
        return [];
      }
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
    if (kIsWeb || _localAuth == null) {
      return {
        'supported': false,
        'enrolled': false,
        'available': false,
        'message': 'المنصة لا تدعم المصادقة البيومترية',
      };
    }
    
    if (!kIsWeb) {
      try {
        // ignore: undefined_class, undefined_getter
        final isDesktop = Platform.isWindows || Platform.isLinux;
        if (isDesktop) {
          return {
            'supported': false,
            'enrolled': false,
            'available': false,
            'message': 'المنصة لا تدعم المصادقة البيومترية',
          };
        }
      } catch (e) {
        return {
          'supported': false,
          'enrolled': false,
          'available': false,
          'message': 'المنصة لا تدعم المصادقة البيومترية',
        };
      }
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
    // على الويب، لا يمكننا استخدام المصادقة البيومترية
    if (kIsWeb) {
      return false;
    }
    
    // Windows و Linux لا يدعمان المصادقة البيومترية
    if (!kIsWeb) {
      try {
        // ignore: undefined_class, undefined_getter
        final isDesktop = Platform.isWindows || Platform.isLinux;
        if (isDesktop) {
          return false;
        }
      } catch (e) {
        return false;
      }
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
    if (kIsWeb || _localAuth == null) {
      return false;
    }
    
    if (!kIsWeb) {
      try {
        // ignore: undefined_class, undefined_getter
        final isDesktop = Platform.isWindows || Platform.isLinux;
        if (isDesktop) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    
    try {
      return await _localAuth!.stopAuthentication();
    } catch (e) {
      return false;
    }
  }
}

