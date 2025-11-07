import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart'; // معطل للوضع المحلي
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  // final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance; // معطل للوضع المحلي

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
    
    // إعداد Firebase Messaging - معطل للوضع المحلي
    // _setupFirebaseMessaging();
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

    // صلاحيات Firebase - معطل للوضع المحلي
    // final settings = await _firebaseMessaging.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    // );
    // print('حالة صلاحيات الإشعارات: ${settings.authorizationStatus}');
  }

  // void _setupFirebaseMessaging() {
  //   // معطل للوضع المحلي
  //   // معالجة الرسائل عندما يكون التطبيق في المقدمة
  //   // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //   //   _showNotification(
  //   //     message.notification?.title ?? 'إشعار جديد',
  //   //     message.notification?.body ?? '',
  //   //   );
  //   // });

  //   // معالجة الرسائل عند النقر على الإشعار
  //   // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  //   //   // معالجة التنقل إلى شاشة معينة
  //   //   print('تم فتح الإشعار: ${message.data}');
  //   // });
  // }

  void _onNotificationTapped(NotificationResponse response) {
    print('تم النقر على الإشعار: ${response.payload}');
    // معالجة التنقل
  }

  Future<void> _showNotification(String title, String body) async {
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
}

