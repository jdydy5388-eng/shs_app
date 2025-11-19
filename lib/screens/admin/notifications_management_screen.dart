import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notification_model.dart';
import '../../services/data_service.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() => _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState extends State<NotificationsManagementScreen> {
  final DataService _dataService = DataService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  NotificationType? _filterType;
  NotificationStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _dataService.getNotifications(
        status: _filterStatus,
      );
      setState(() {
        _notifications = notifications.cast<NotificationModel>();
        if (_filterType != null) {
          _notifications = _notifications.where((n) => n.type == _filterType).toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الإشعارات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الإشعارات'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'type') {
                _showTypeFilter();
              } else if (value == 'status') {
                _showStatusFilter();
              } else if (value == 'clear') {
                setState(() {
                  _filterType = null;
                  _filterStatus = null;
                });
                _loadNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'type', child: Text('فلترة حسب النوع')),
              const PopupMenuItem(value: 'status', child: Text('فلترة حسب الحالة')),
              const PopupMenuItem(value: 'clear', child: Text('إزالة الفلاتر')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد إشعارات',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
            ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    
    final typeIcon = {
      NotificationType.sms: Icons.sms,
      NotificationType.email: Icons.email,
    }[notification.type]!;

    final typeColor = {
      NotificationType.sms: Colors.blue,
      NotificationType.email: Colors.green,
    }[notification.type]!;

    final statusColor = {
      NotificationStatus.scheduled: Colors.orange,
      NotificationStatus.sent: Colors.green,
      NotificationStatus.failed: Colors.red,
      NotificationStatus.cancelled: Colors.grey,
    }[notification.status]!;

    final statusText = {
      NotificationStatus.scheduled: 'مجدولة',
      NotificationStatus.sent: 'مرسلة',
      NotificationStatus.failed: 'فاشلة',
      NotificationStatus.cancelled: 'ملغاة',
    }[notification.status]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.2),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(
          notification.type == NotificationType.email && notification.subject != null
              ? notification.subject!
              : notification.recipient,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المستقبل: ${notification.recipient}'),
            Text('الرسالة: ${notification.message}'),
            Text('مجدولة لـ: ${dateFormat.format(notification.scheduledAt)}'),
            if (notification.sentAt != null)
              Text('تم الإرسال: ${dateFormat.format(notification.sentAt!)}', style: const TextStyle(color: Colors.green)),
            if (notification.error != null)
              Text('خطأ: ${notification.error}', style: const TextStyle(color: Colors.red)),
          ],
        ),
        trailing: Chip(
          label: Text(statusText, style: const TextStyle(fontSize: 12)),
          backgroundColor: statusColor.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب النوع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<NotificationType?>(
              title: const Text('جميع الأنواع'),
              value: null,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
                _loadNotifications();
              },
            ),
            RadioListTile<NotificationType?>(
              title: const Text('SMS'),
              value: NotificationType.sms,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
                _loadNotifications();
              },
            ),
            RadioListTile<NotificationType?>(
              title: const Text('Email'),
              value: NotificationType.email,
              groupValue: _filterType,
              onChanged: (value) {
                setState(() => _filterType = value);
                Navigator.pop(context);
                _loadNotifications();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة حسب الحالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<NotificationStatus?>(
              title: const Text('جميع الحالات'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadNotifications();
              },
            ),
            RadioListTile<NotificationStatus?>(
              title: const Text('مجدولة'),
              value: NotificationStatus.scheduled,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadNotifications();
              },
            ),
            RadioListTile<NotificationStatus?>(
              title: const Text('مرسلة'),
              value: NotificationStatus.sent,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadNotifications();
              },
            ),
            RadioListTile<NotificationStatus?>(
              title: const Text('فاشلة'),
              value: NotificationStatus.failed,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _loadNotifications();
              },
            ),
          ],
        ),
      ),
    );
  }
}

