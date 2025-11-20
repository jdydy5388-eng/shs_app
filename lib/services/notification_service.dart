import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../providers/auth_provider_local.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // Firebase Messaging متاح فقط على Android, iOS, Web
  // على Windows، لن يتم استخدام Firebase
  // Note: تم تعطيل Firebase على Windows لتجنب أخطاء الربط
  // dynamic _firebaseMessaging;

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
    
    // إعداد Firebase Messaging
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
    // على Windows، تخطي Firebase
    if (!Platform.isWindows) {
      // Note: تم تعطيل Firebase على Windows
      // final settings = await _firebaseMessaging.requestPermission(...);
      print('Firebase permissions skipped on Windows');
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // على Windows، تخطي Firebase Messaging تماماً
    if (Platform.isWindows) {
      print('Firebase Messaging غير متاح على Windows - سيتم استخدام الإشعارات المحلية فقط');
      return;
    }
    
    try {
      // Note: تم تعطيل Firebase على Windows
      // على Android/iOS/Web، سيتم استخدام Firebase
      // final token = await _firebaseMessaging.getToken();
      // ...
      print('Firebase Messaging initialization skipped on Windows');
    } catch (e) {
      print('Warning: Firebase Messaging غير متاح: $e');
      print('الإشعارات المحلية ستعمل بشكل طبيعي');
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // معالجة التنقل بناءً على نوع الإشعار
    // مثال: إذا كان type == 'appointment' انتقل إلى شاشة المواعيد
    print('معالجة التنقل: $data');
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('تم النقر على الإشعار: ${response.payload}');
    // معالجة التنقل
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
          print('تم حفظ FCM Token في الخادم');
        } catch (e) {
          // إذا فشل الحفظ في الخادم، نستمر (الـ token محفوظ محلياً)
          print('لم يتم حفظ FCM Token في الخادم: $e');
        }
      }
      
      print('تم حفظ FCM Token محلياً');
    } catch (e) {
      print('خطأ في حفظ FCM Token: $e');
    }
  }

  /// الحصول على FCM Token المحفوظ
  Future<String?> getSavedFCMToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      print('خطأ في قراءة FCM Token: $e');
      return null;
    }
  }
}

