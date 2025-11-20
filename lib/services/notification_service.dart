import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../providers/auth_provider_local.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

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

    // صلاحيات Firebase
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('حالة صلاحيات الإشعارات: ${settings.authorizationStatus}');
  }

  Future<void> _setupFirebaseMessaging() async {
    // الحصول على FCM Token
    final token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
    
    // حفظ الـ token في قاعدة البيانات
    if (token != null) {
      await _saveFCMToken(token);
    }
    
    // تحديث الـ token عند تغييره
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('FCM Token تم تحديثه: $newToken');
      // تحديث الـ token في قاعدة البيانات
      await _saveFCMToken(newToken);
    });

    // معالجة الرسائل عندما يكون التطبيق في المقدمة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('تم استقبال إشعار: ${message.notification?.title}');
      _showNotification(
        message.notification?.title ?? 'إشعار جديد',
        message.notification?.body ?? '',
        payload: message.data.toString(),
      );
    });

    // معالجة الرسائل عند النقر على الإشعار (عندما يكون التطبيق في الخلفية)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('تم فتح الإشعار: ${message.data}');
      // معالجة التنقل إلى شاشة معينة بناءً على البيانات
      _handleNotificationNavigation(message.data);
    });

    // معالجة الإشعار عند فتح التطبيق من إشعار (عندما يكون التطبيق مغلق)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
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
      final prefs = await SharedPreferences.getInstance();
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

