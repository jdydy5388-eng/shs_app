import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/data_service.dart';

// Firebase imports - فقط على المنصات المدعومة
// على Windows، سيتم تخطي Firebase في runtime لتجنب مشاكل الربط C++
import 'package:firebase_messaging/firebase_messaging.dart';

FirebaseMessaging? _firebaseMessaging;
bool _isFirebaseAvailable = false;

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // تهيئة الإشعارات المحلية
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // إعداد Firebase Messaging أولاً (فقط على Android/iOS/Web)
    await _setupFirebaseMessaging();
    
    // طلب صلاحيات الإشعارات (بعد تهيئة Firebase)
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    debugPrint('🔄 طلب صلاحيات الإشعارات...');
    
    // صلاحيات Android (Android 13+)
    if (Platform.isAndroid) {
      try {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          debugPrint('🔄 طلب صلاحيات Android...');
          final granted = await androidPlugin.requestNotificationsPermission();
          if (granted == true) {
            debugPrint('✅ صلاحيات Android مُعطاة');
          } else {
            debugPrint('⚠️ صلاحيات Android غير مُعطاة');
          }
        }
      } catch (e) {
        debugPrint('❌ خطأ في طلب صلاحيات Android: $e');
      }
    }

    // صلاحيات iOS
    if (Platform.isIOS) {
      try {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        
        if (iosPlugin != null) {
          debugPrint('🔄 طلب صلاحيات iOS...');
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          debugPrint('✅ صلاحيات iOS: $granted');
        }
      } catch (e) {
        debugPrint('❌ خطأ في طلب صلاحيات iOS: $e');
      }
      
      // صلاحيات Firebase (iOS فقط - requestPermission يعمل فقط على iOS)
      if (_isFirebaseAvailable && _firebaseMessaging != null) {
        try {
          debugPrint('🔄 طلب صلاحيات Firebase (iOS)...');
          final settings = await _firebaseMessaging!.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          debugPrint('✅ Firebase permissions: ${settings.authorizationStatus}');
        } catch (e) {
          debugPrint('⚠️ خطأ في طلب صلاحيات Firebase: $e');
        }
      }
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // على Windows، تخطي Firebase Messaging تماماً
    if (Platform.isWindows) {
      debugPrint('ℹ️ Windows detected - Firebase Messaging غير متاح، سيتم استخدام الإشعارات المحلية فقط');
      _isFirebaseAvailable = false;
      return;
    }
    
    try {
      debugPrint('🔄 بدء تهيئة Firebase Messaging...');
      
      // استخدام Firebase Messaging
      _firebaseMessaging = FirebaseMessaging.instance;
      _isFirebaseAvailable = true;
      debugPrint('✅ Firebase Messaging instance created');

      // التحقق من أن Firebase Messaging متاح
      if (_firebaseMessaging == null) {
        debugPrint('⚠️ Firebase Messaging instance is null');
        _isFirebaseAvailable = false;
        return;
      }

      final messaging = _firebaseMessaging!;

      // ملاحظة: requestPermission() يعمل فقط على iOS
      // على Android، يتم طلب الصلاحيات من requestPermissions() في initialize()
      
      // الحصول على FCM Token
      try {
        debugPrint('🔄 جاري الحصول على FCM Token...');
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('✅ FCM Token: $token');
          await _saveFCMToken(token);
        } else {
          debugPrint('⚠️ FCM Token is null or empty');
        }
      } catch (e) {
        debugPrint('❌ خطأ في الحصول على FCM Token: $e');
        // لا نوقف التهيئة، قد يعمل لاحقاً
      }

      // تحديث الـ token عند تغييره
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM Token تم تحديثه: $newToken');
        await _saveFCMToken(newToken);
      });

      // معالجة الرسائل عندما يكون التطبيق في المقدمة
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 إشعار جديد: ${message.notification?.title}');
        _showNotification(
          message.notification?.title ?? 'إشعار جديد',
          message.notification?.body ?? '',
          payload: message.data.toString(),
        );
      });

      // معالجة الرسائل عند النقر على الإشعار (عندما يكون التطبيق في الخلفية)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('👆 تم فتح الإشعار: ${message.data}');
        _handleNotificationNavigation(message.data);
      });

      // معالجة الإشعار عند فتح التطبيق من إشعار (عندما يكون التطبيق مغلق)
      try {
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('📱 تم فتح التطبيق من إشعار');
          _handleNotificationNavigation(initialMessage.data);
        }
      } catch (e) {
        debugPrint('⚠️ خطأ في getInitialMessage: $e');
      }

      debugPrint('✅ Firebase Messaging initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ خطأ في تهيئة Firebase Messaging: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('الإشعارات المحلية ستعمل بشكل طبيعي');
      _isFirebaseAvailable = false;
      _firebaseMessaging = null;
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // معالجة التنقل بناءً على نوع الإشعار
    // مثال: إذا كان type == 'appointment' انتقل إلى شاشة المواعيد
    debugPrint('معالجة التنقل: $data');
    // TODO: إضافة منطق التنقل بناءً على نوع الإشعار
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('تم النقر على الإشعار: ${response.payload}');
    // TODO: إضافة منطق التنقل عند النقر على الإشعار المحلي
  }

  Future<void> _showNotification(String title, String body, {String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'تنبيهات الأدوية',
      channelDescription: 'إشعارات لتذكير تناول الأدوية',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// جدولة تذكير لتناول الدواء
  Future<void> scheduleMedicationReminder({
    required int id,
    required String medicationName,
    required String dosage,
    required DateTime scheduledTime,
    required int intervalDays,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'تنبيهات الأدوية',
      channelDescription: 'إشعارات لتذكير تناول الأدوية',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      'وقت تناول الدواء',
      'يرجى تناول: $medicationName - الجرعة: $dosage',
      _convertToTZDateTime(scheduledTime),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// حذف تذكير محدد
  Future<void> cancelReminder(int id) async {
    await _localNotifications.cancel(id);
  }

  /// حذف جميع التذكيرات
  Future<void> cancelAllReminders() async {
    await _localNotifications.cancelAll();
  }

  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    // تحويل DateTime إلى TZDateTime في المنطقة الزمنية المحلية
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// إرسال إشعار فوري
  Future<void> sendInstantNotification(String title, String body) async {
    await _showNotification(title, body);
  }

  /// حفظ FCM Token في قاعدة البيانات
  Future<void> _saveFCMToken(String token) async {
    try {
      // حفظ محلياً في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      
      // محاولة حفظ في الخادم إذا كان المستخدم مسجل دخول
      // سيتم استدعاء هذه الدالة من context حيث يمكن الوصول إلى Provider
      // أو يمكن حفظ userId في SharedPreferences عند تسجيل الدخول
      final userId = prefs.getString('current_user_id');
      if (userId != null) {
        try {
          final dataService = DataService();
          await dataService.saveFCMToken(userId, token);
          debugPrint('✅ تم حفظ FCM Token في الخادم');
        } catch (e) {
          // إذا فشل الحفظ في الخادم، نستمر (الـ token محفوظ محلياً)
          debugPrint('⚠️ لم يتم حفظ FCM Token في الخادم: $e');
        }
      }
      
      debugPrint('✅ تم حفظ FCM Token محلياً');
    } catch (e) {
      debugPrint('❌ خطأ في حفظ FCM Token: $e');
    }
  }

  /// الحصول على FCM Token المحفوظ
  Future<String?> getSavedFCMToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      debugPrint('❌ خطأ في قراءة FCM Token: $e');
      return null;
    }
  }

  /// إرسال إشعار Firebase (للاختبار)
  Future<void> sendFirebaseNotification(String title, String body) async {
    if (!_isFirebaseAvailable) {
      debugPrint('⚠️ Firebase غير متاح - استخدام الإشعارات المحلية');
      await sendInstantNotification(title, body);
      return;
    }
    // ملاحظة: إرسال إشعارات Firebase يتم من الخادم
    // هذه الدالة للاختبار فقط
    await sendInstantNotification(title, body);
  }

  /// اختبار الإشعارات - يعرض FCM Token وإرسال إشعار تجريبي
  Future<Map<String, dynamic>> testNotifications() async {
    final result = <String, dynamic>{
      'firebaseAvailable': _isFirebaseAvailable,
      'fcmToken': null,
      'localNotificationTest': false,
    };

    try {
      // محاولة إعادة تهيئة Firebase Messaging إذا لم يكن متاحاً
      if (!_isFirebaseAvailable && !Platform.isWindows) {
        debugPrint('🔄 محاولة إعادة تهيئة Firebase Messaging...');
        await _setupFirebaseMessaging();
      }

      // الحصول على FCM Token
      if (_isFirebaseAvailable && _firebaseMessaging != null) {
        try {
          final token = await _firebaseMessaging!.getToken();
          result['fcmToken'] = token;
          debugPrint('✅ FCM Token للاختبار: $token');
          
          // حفظ الـ token
          if (token != null) {
            await _saveFCMToken(token);
          }
        } catch (e) {
          debugPrint('⚠️ خطأ في الحصول على FCM Token: $e');
          // محاولة الحصول على token محفوظ
          result['fcmToken'] = await getSavedFCMToken();
          if (result['fcmToken'] != null) {
            debugPrint('ℹ️ استخدام FCM Token المحفوظ: ${result['fcmToken']}');
          } else {
            debugPrint('⚠️ لا يوجد FCM Token متاح');
          }
        }
      } else {
        result['fcmToken'] = await getSavedFCMToken();
        if (result['fcmToken'] != null) {
          debugPrint('ℹ️ استخدام FCM Token المحفوظ: ${result['fcmToken']}');
        } else {
          debugPrint('⚠️ لا يوجد FCM Token متاح - Firebase غير متاح أو لم يتم تهيئته');
        }
      }

      // إرسال إشعار تجريبي محلي
      await sendInstantNotification(
        'اختبار الإشعارات',
        'هذا إشعار تجريبي. إذا رأيت هذا، فالإشعارات تعمل بشكل صحيح! ✅',
      );
      result['localNotificationTest'] = true;

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ خطأ في اختبار الإشعارات: $e');
      debugPrint('Stack trace: $stackTrace');
      result['error'] = e.toString();
      return result;
    }
  }

  /// الحصول على معلومات حالة Firebase
  Map<String, dynamic> getFirebaseStatus() {
    return {
      'isAvailable': _isFirebaseAvailable,
      'hasMessaging': _firebaseMessaging != null,
      'platform': Platform.operatingSystem,
    };
  }
}

