import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/data_service.dart';
import '../services/notification_service.dart';

/// Provider لإدارة الإشعارات الفورية والمجدولة
class NotificationProvider extends ChangeNotifier {
  final DataService _dataService = DataService();
  final NotificationService _notificationService = NotificationService();
  
  List<NotificationModel> _notifications = [];
  List<InAppNotification> _inAppNotifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  List<InAppNotification> get inAppNotifications => _inAppNotifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  
  // Getter للوصول إلى خدمة الإشعارات من خارج الكلاس
  NotificationService get notificationService => _notificationService;

  /// تحميل الإشعارات من الخادم
  Future<void> loadNotifications({String? userId, NotificationStatus? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final notifications = await _dataService.getNotifications(
        status: status,
        relatedType: userId != null ? 'user' : null,
        relatedId: userId,
      );
      _notifications = notifications.cast<NotificationModel>();
      _unreadCount = _notifications.where((n) => n.status == NotificationStatus.sent).length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// إضافة إشعار فوري داخل التطبيق
  void addInAppNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.sms,
    IconData? icon,
    Color? color,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final notification = InAppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      icon: icon ?? _getDefaultIcon(type),
      color: color ?? _getDefaultColor(type),
      actionLabel: actionLabel,
      onAction: onAction,
      createdAt: DateTime.now(),
    );

    _inAppNotifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();

    // إزالة الإشعار تلقائياً بعد المدة المحددة
    final removeDuration = duration ?? const Duration(seconds: 5);
    Future.delayed(removeDuration, () {
      removeInAppNotification(notification.id);
    });
  }

  /// إزالة إشعار فوري
  void removeInAppNotification(String id) {
    _inAppNotifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// إزالة جميع الإشعارات الفورية
  void clearInAppNotifications() {
    _inAppNotifications.clear();
    notifyListeners();
  }

  /// جدولة إشعار
  Future<void> scheduleNotification({
    required NotificationType type,
    required String recipient,
    required String message,
    String? subject,
    required DateTime scheduledAt,
    String? relatedType,
    String? relatedId,
  }) async {
    try {
      // إنشاء NotificationModel
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        recipient: recipient,
        subject: subject,
        message: message,
        scheduledAt: scheduledAt,
        status: NotificationStatus.scheduled,
        relatedType: relatedType,
        relatedId: relatedId,
        createdAt: DateTime.now(),
      );

      // حفظ الإشعار
      await _dataService.scheduleNotification(notification);

      _notifications.insert(0, notification);
      notifyListeners();

      // جدولة إشعار محلي إذا كان SMS
      if (type == NotificationType.sms) {
        await _notificationService.scheduleMedicationReminder(
          id: int.parse(notification.id.substring(0, 8), radix: 16),
          medicationName: message,
          dosage: '',
          scheduledTime: scheduledAt,
          intervalDays: 1,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// تحديث حالة الإشعار
  Future<void> updateNotificationStatus(
    String notificationId,
    NotificationStatus status,
  ) async {
    try {
      await _dataService.updateNotificationStatus(notificationId, status);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          type: _notifications[index].type,
          recipient: _notifications[index].recipient,
          subject: _notifications[index].subject,
          message: _notifications[index].message,
          scheduledAt: _notifications[index].scheduledAt,
          status: status,
          relatedType: _notifications[index].relatedType,
          relatedId: _notifications[index].relatedId,
          createdAt: _notifications[index].createdAt,
          sentAt: status == NotificationStatus.sent ? DateTime.now() : _notifications[index].sentAt,
          error: _notifications[index].error,
        );
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// إرسال إشعار فوري (محلي + خادم)
  Future<void> sendInstantNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.sms,
    String? recipient,
    IconData? icon,
    Color? color,
  }) async {
    // إشعار محلي فوري
    await _notificationService.sendInstantNotification(title, message);

    // إضافة إشعار داخل التطبيق
    addInAppNotification(
      title: title,
      message: message,
      type: type,
      icon: icon,
      color: color,
    );

    // حفظ في الخادم إذا كان هناك مستلم
    if (recipient != null) {
      try {
        await scheduleNotification(
          type: type,
          recipient: recipient,
          message: message,
          scheduledAt: DateTime.now(),
        );
      } catch (e) {
        // تجاهل الأخطاء في الحفظ
      }
    }
  }

  IconData _getDefaultIcon(NotificationType type) {
    switch (type) {
      case NotificationType.sms:
        return Icons.message;
      case NotificationType.email:
        return Icons.email;
    }
  }

  Color _getDefaultColor(NotificationType type) {
    switch (type) {
      case NotificationType.sms:
        return Colors.blue;
      case NotificationType.email:
        return Colors.green;
    }
  }
}

/// نموذج للإشعار الفوري داخل التطبيق
class InAppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DateTime createdAt;
  bool isRead;

  InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
    required this.createdAt,
    this.isRead = false,
  });
}

