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

    // طلب صلاحيات الإشعارات
    await requestPermissions();
    
    // إعداد Firebase Messaging (فقط على Android/iOS/Web)
    await _setupFirebaseMessaging();
  }

  Future<void> requestPermissions() async {
    // صلاحيات Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // صلاحيات iOS
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // صلاحيات Firebase (فقط على المنصات المدعومة)
    if (!Platform.isWindows && _isFirebaseAvailable && _firebaseMessaging != null) {
      try {
        final settings = await _firebaseMessaging!.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('Firebase permissions: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('خطأ في طلب صلاحيات Firebase: $e');
      }
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // على Windows، تخطي Firebase Messaging تماماً
    if (Platform.isWindows) {
      debugPrint('ℹ️ Windows detected - Firebase Messaging غير متاح، سيتم استخدام الإشعارات المحلية فقط');
      return;
    }
    
    try {
      // استخدام Firebase Messaging (سيتم تخطيه على Windows تلقائياً)
      // Note: على Windows، سيتم رمي exception هنا
      _firebaseMessaging = FirebaseMessaging.instance;
      _isFirebaseAvailable = true;

      // التحقق من أن Firebase Messaging متاح
      if (_firebaseMessaging == null) {
        debugPrint('⚠️ Firebase Messaging instance is null');
        return;
      }

      final messaging = _firebaseMessaging!;

      // الحصول على FCM Token
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('✅ FCM Token: $token');
        await _saveFCMToken(token);
      }

      // تحديث الـ token عند تغييره
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM Token تم تحديثه: $newToken');
        await _saveFCMToken(newToken);
      });

      // معالجة الرسائل عندما يكون التطبيق في المقدمة
      // Note: onMessage و onMessageOpenedApp هما static getters في FirebaseMessaging
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
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationNavigation(initialMessage.data);
      }

      debugPrint('✅ Firebase Messaging initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Warning: Firebase Messaging غير متاح: $e');
      debugPrint('الإشعارات المحلية ستعمل بشكل طبيعي');
      _isFirebaseAvailable = false;
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
      // الحصول على FCM Token
      if (_isFirebaseAvailable && _firebaseMessaging != null) {
        final token = await _firebaseMessaging!.getToken();
        result['fcmToken'] = token;
        debugPrint('✅ FCM Token للاختبار: $token');
      } else {
        result['fcmToken'] = await getSavedFCMToken();
        debugPrint('ℹ️ استخدام FCM Token المحفوظ: ${result['fcmToken']}');
      }

      // إرسال إشعار تجريبي محلي
      await sendInstantNotification(
        'اختبار الإشعارات',
        'هذا إشعار تجريبي. إذا رأيت هذا، فالإشعارات تعمل بشكل صحيح! ✅',
      );
      result['localNotificationTest'] = true;

      return result;
    } catch (e) {
      debugPrint('❌ خطأ في اختبار الإشعارات: $e');
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

