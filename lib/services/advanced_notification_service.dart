import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_model.dart';
import '../models/doctor_appointment_model.dart';
import '../models/hospital_pharmacy_model.dart';
import '../models/emergency_case_model.dart';
import '../models/lab_test_type_model.dart';
import '../models/user_model.dart';
import '../services/data_service.dart';
import 'notification_service.dart';

enum NotificationPriority {
  low,
  normal,
  high,
  critical,
}

class AdvancedNotificationService {
  final NotificationService _localNotificationService = NotificationService();
  final DataService _dataService = DataService();
  Timer? _monitoringTimer;

  Future<void> initialize() async {
    await _localNotificationService.initialize();
    _startMonitoring();
  }

  void _startMonitoring() {
    // مراقبة كل دقيقة للتحقق من الإشعارات المستحقة
    _monitoringTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkScheduledNotifications();
      _checkMedicationReminders();
      _checkAppointmentReminders();
      _checkCriticalCases();
    });
  }

  void dispose() {
    _monitoringTimer?.cancel();
  }

  // إشعارات فورية (Push Notifications)
  Future<void> sendPushNotification({
    required String title,
    required String body,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? data,
    String? targetUserId, // ID المستخدم المستهدف
  }) async {
    // إرسال إشعار محلي
    await _localNotificationService.sendInstantNotification(title, body);
    
    // إرسال إشعار عبر Firebase (إذا كان هناك مستخدم مستهدف)
    if (targetUserId != null) {
      await _sendFirebaseNotification(
        title: title,
        body: body,
        priority: priority,
        data: data,
        targetUserId: targetUserId,
      );
    }
  }

  // إرسال إشعار عبر Firebase Cloud Messaging
  Future<void> _sendFirebaseNotification({
    required String title,
    required String body,
    required NotificationPriority priority,
    Map<String, dynamic>? data,
    required String targetUserId,
  }) async {
    try {
      // الحصول على FCM Token للمستخدم المستهدف من قاعدة البيانات
      // TODO: إضافة endpoint في الخادم لإرسال الإشعارات
      // يمكن استخدام Firebase Admin SDK في الخادم لإرسال الإشعارات
      
      // مثال على الاستخدام:
      // final response = await http.post(
      //   Uri.parse('$baseUrl/api/notifications/send'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'userId': targetUserId,
      //     'title': title,
      //     'body': body,
      //     'priority': priority.toString(),
      //     'data': data,
      //   }),
      // );
      
      debugPrint('إرسال إشعار Firebase إلى المستخدم: $targetUserId');
    } catch (e) {
      debugPrint('خطأ في إرسال إشعار Firebase: $e');
    }
  }

  // إشعارات SMS
  Future<void> sendSMSNotification({
    required String recipient,
    required String message,
    DateTime? scheduledAt,
  }) async {
    try {
      final notification = NotificationModel(
        id: _dataService.generateId(),
        type: NotificationType.sms,
        recipient: recipient,
        message: message,
        scheduledAt: scheduledAt ?? DateTime.now(),
        status: scheduledAt != null && scheduledAt.isAfter(DateTime.now())
            ? NotificationStatus.scheduled
            : NotificationStatus.sent,
        createdAt: DateTime.now(),
        sentAt: scheduledAt == null || scheduledAt.isBefore(DateTime.now())
            ? DateTime.now()
            : null,
      );

      await _dataService.scheduleNotification(notification);
      
      // في الوضع الحقيقي، يمكن استخدام خدمة SMS مثل Twilio
      // await _sendSMSViaAPI(recipient, message);
      
      if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
        await _dataService.updateNotificationStatus(notification.id, NotificationStatus.sent);
      }
    } catch (e) {
      debugPrint('خطأ في إرسال SMS: $e');
    }
  }

  // إشعارات Email
  Future<void> sendEmailNotification({
    required String recipient,
    required String subject,
    required String message,
    DateTime? scheduledAt,
  }) async {
    try {
      final notification = NotificationModel(
        id: _dataService.generateId(),
        type: NotificationType.email,
        recipient: recipient,
        subject: subject,
        message: message,
        scheduledAt: scheduledAt ?? DateTime.now(),
        status: scheduledAt != null && scheduledAt.isAfter(DateTime.now())
            ? NotificationStatus.scheduled
            : NotificationStatus.sent,
        createdAt: DateTime.now(),
        sentAt: scheduledAt == null || scheduledAt.isBefore(DateTime.now())
            ? DateTime.now()
            : null,
      );

      await _dataService.scheduleNotification(notification);
      
      // في الوضع الحقيقي، يمكن استخدام خدمة Email مثل SendGrid أو SMTP
      // await _sendEmailViaAPI(recipient, subject, message);
      
      if (scheduledAt == null || scheduledAt.isBefore(DateTime.now())) {
        await _dataService.updateNotificationStatus(notification.id, NotificationStatus.sent);
      }
    } catch (e) {
      debugPrint('خطأ في إرسال Email: $e');
    }
  }

  // إشعارات مواعيد الأدوية التلقائية
  Future<void> scheduleMedicationNotifications({
    required String patientId,
    required String medicationName,
    required String dosage,
    required List<DateTime> scheduledTimes,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    for (final scheduledTime in scheduledTimes) {
      if (endDate != null && scheduledTime.isAfter(endDate)) continue;
      if (scheduledTime.isBefore(startDate)) continue;

      final notificationId = scheduledTime.millisecondsSinceEpoch ~/ 1000;
      
      await _localNotificationService.scheduleMedicationReminder(
        id: notificationId,
        medicationName: medicationName,
        dosage: dosage,
        scheduledTime: scheduledTime,
        intervalDays: 0, // يومياً
      );

      // إرسال SMS و Email أيضاً
      try {
        final patient = await _dataService.getUser(patientId);
        if (patient != null && patient is UserModel) {
          final smsMessage = 'تذكير: حان وقت تناول $medicationName - الجرعة: $dosage';
          
          if (patient.phone != null && patient.phone!.isNotEmpty) {
            await sendSMSNotification(
              recipient: patient.phone!,
              message: smsMessage,
              scheduledAt: scheduledTime.subtract(const Duration(minutes: 15)), // 15 دقيقة قبل الموعد
            );
          }

          if (patient.email != null && patient.email!.isNotEmpty) {
            await sendEmailNotification(
              recipient: patient.email!,
              subject: 'تذكير تناول الدواء',
              message: smsMessage,
              scheduledAt: scheduledTime.subtract(const Duration(hours: 1)), // ساعة قبل الموعد
            );
          }
        }
      } catch (e) {
        debugPrint('خطأ في جدولة إشعارات الدواء: $e');
      }
    }
  }

  // إشعارات المواعيد
  Future<void> scheduleAppointmentNotifications(DoctorAppointment appointment) async {
    try {
      if (appointment.patientId == null) return;
      final patient = await _dataService.getUser(appointment.patientId!);
      if (patient == null || patient is! UserModel) return;

      // إشعار قبل الموعد بـ 24 ساعة
      final reminder24h = appointment.date.subtract(const Duration(hours: 24));
      if (reminder24h.isAfter(DateTime.now())) {
        await sendPushNotification(
          title: 'تذكير موعد',
          body: 'لديك موعد غداً في ${appointment.date.toString().substring(0, 16)}',
          priority: NotificationPriority.normal,
        );

        if (patient.phone != null && patient.phone!.isNotEmpty) {
          await sendSMSNotification(
            recipient: patient.phone!,
            message: 'تذكير: لديك موعد غداً في ${appointment.date.toString().substring(0, 16)}',
            scheduledAt: reminder24h,
          );
        }

        if (patient.email != null) {
          await sendEmailNotification(
            recipient: patient.email!,
            subject: 'تذكير موعد',
            message: 'لديك موعد غداً في ${appointment.date.toString().substring(0, 16)}',
            scheduledAt: reminder24h,
          );
        }
      }

      // إشعار قبل الموعد بساعتين
      final reminder2h = appointment.date.subtract(const Duration(hours: 2));
      if (reminder2h.isAfter(DateTime.now())) {
        await sendPushNotification(
          title: 'تذكير موعد قريب',
          body: 'لديك موعد خلال ساعتين في ${appointment.date.toString().substring(0, 16)}',
          priority: NotificationPriority.high,
        );

        if (patient.phone != null && patient.phone!.isNotEmpty) {
          await sendSMSNotification(
            recipient: patient.phone!,
            message: 'تذكير: لديك موعد خلال ساعتين',
            scheduledAt: reminder2h,
          );
        }
      }
    } catch (e) {
      debugPrint('خطأ في جدولة إشعارات الموعد: $e');
    }
  }

  // إشعارات الحالات الحرجة
  Future<void> sendCriticalCaseNotification(EmergencyCaseModel emergencyCase) async {
    if (emergencyCase.triageLevel != TriageLevel.red) return;

    await sendPushNotification(
      title: '⚠️ حالة حرجة',
      body: 'حالة حرجة تحتاج تدخل فوري: ${emergencyCase.patientName ?? "مريض"}',
      priority: NotificationPriority.critical,
    );

    // إشعار الأطباء والطاقم الطبي
    try {
      final doctors = await _dataService.getUsers(role: 'doctor');
      for (final doctor in doctors) {
        if (doctor is UserModel) {
          if (doctor.phone != null && doctor.phone!.isNotEmpty) {
            await sendSMSNotification(
              recipient: doctor.phone!,
              message: 'تنبيه: حالة حرجة في الطوارئ تحتاج تدخل فوري',
            );
          }

          if (doctor.email != null && doctor.email!.isNotEmpty) {
            await sendEmailNotification(
              recipient: doctor.email!,
              subject: '⚠️ حالة حرجة - تدخل فوري',
              message: 'حالة حرجة في الطوارئ تحتاج تدخل فوري: ${emergencyCase.patientName ?? "مريض"}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في إرسال إشعارات الحالة الحرجة: $e');
    }
  }

  // إشعارات نتائج الفحوصات الحرجة
  Future<void> sendCriticalLabResultNotification(LabResultModel result, String patientName) async {
    if (!result.isCritical) return;

    await sendPushNotification(
      title: '⚠️ نتائج حرجة',
      body: 'نتائج فحص حرجة للمريض: $patientName',
      priority: NotificationPriority.critical,
    );
  }

  // التحقق من الإشعارات المجدولة
  Future<void> _checkScheduledNotifications() async {
    try {
      final notifications = await _dataService.getNotifications(
        status: NotificationStatus.scheduled,
      );

      final now = DateTime.now();
      for (final notification in notifications) {
        if (notification is NotificationModel) {
          if (notification.scheduledAt.isBefore(now) ||
              notification.scheduledAt.isAtSameMomentAs(now)) {
            // إرسال الإشعار
            if (notification.type == NotificationType.sms) {
              await sendSMSNotification(
                recipient: notification.recipient,
                message: notification.message,
              );
            } else if (notification.type == NotificationType.email) {
              await sendEmailNotification(
                recipient: notification.recipient,
                subject: notification.subject ?? '',
                message: notification.message,
              );
            }

            await _dataService.updateNotificationStatus(
              notification.id,
              NotificationStatus.sent,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من الإشعارات المجدولة: $e');
    }
  }

  // التحقق من تذكيرات الأدوية
  Future<void> _checkMedicationReminders() async {
    try {
      final now = DateTime.now();
      final dispenses = await _dataService.getHospitalPharmacyDispenses(
        status: MedicationDispenseStatus.scheduled,
        from: now.subtract(const Duration(minutes: 5)),
        to: now.add(const Duration(minutes: 5)),
      );

      for (final dispense in dispenses) {
        if (dispense is HospitalPharmacyDispenseModel) {
          if (dispense.scheduledTime.isBefore(now) ||
              dispense.scheduledTime.isAtSameMomentAs(now)) {
            await sendPushNotification(
              title: '⏰ وقت تناول الدواء',
              body: 'حان وقت تناول ${dispense.medicationName} - الجرعة: ${dispense.dosage}',
              priority: NotificationPriority.high,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من تذكيرات الأدوية: $e');
    }
  }

  // التحقق من تذكيرات المواعيد
  Future<void> _checkAppointmentReminders() async {
    try {
      final now = DateTime.now();
      // الحصول على جميع المواعيد من جميع الأطباء
      final doctors = await _dataService.getUsers(role: 'doctor');
      final List<DoctorAppointment> allAppointments = [];
      for (var doctor in doctors) {
        final doctorAppointments = await _dataService.getDoctorAppointments(doctor.id);
        allAppointments.addAll(doctorAppointments.cast<DoctorAppointment>());
      }
      final appointments = allAppointments;

      for (final appointment in appointments) {
        if (appointment is DoctorAppointment) {
          // إشعار قبل 24 ساعة
          final reminder24h = appointment.date.subtract(const Duration(hours: 24));
          if (reminder24h.isAtSameMomentAs(now) || 
              (reminder24h.isBefore(now) && reminder24h.isAfter(now.subtract(const Duration(minutes: 1))))) {
            await scheduleAppointmentNotifications(appointment);
          }

          // إشعار قبل ساعتين
          final reminder2h = appointment.date.subtract(const Duration(hours: 2));
          if (reminder2h.isAtSameMomentAs(now) ||
              (reminder2h.isBefore(now) && reminder2h.isAfter(now.subtract(const Duration(minutes: 1))))) {
            await scheduleAppointmentNotifications(appointment);
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من تذكيرات المواعيد: $e');
    }
  }

  // التحقق من الحالات الحرجة
  Future<void> _checkCriticalCases() async {
    try {
      final emergencyCases = await _dataService.getEmergencyCases(
        status: EmergencyStatus.waiting,
        triage: TriageLevel.red,
      );

      for (final case_ in emergencyCases) {
        if (case_ is EmergencyCaseModel) {
          // إرسال إشعار إذا كانت الحالة جديدة (أقل من 5 دقائق)
          final caseAge = DateTime.now().difference(case_.createdAt);
          if (caseAge.inMinutes < 5) {
            await sendCriticalCaseNotification(case_);
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من الحالات الحرجة: $e');
    }
  }
}

