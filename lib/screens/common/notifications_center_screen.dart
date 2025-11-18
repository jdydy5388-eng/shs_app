import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/loading_widgets.dart';
import '../../widgets/status_banner.dart';

/// شاشة مركزية لعرض جميع الإشعارات
class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() => _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  NotificationType? _filterType;
  NotificationStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.loadNotifications();
  }

  List<NotificationModel> get _filteredNotifications {
    final provider = Provider.of<NotificationProvider>(context);
    var filtered = provider.notifications;

    // فلترة حسب النوع
    if (_filterType != null) {
      filtered = filtered.where((n) => n.type == _filterType).toList();
    }

    // فلترة حسب الحالة
    if (_filterStatus != null) {
      filtered = filtered.where((n) => n.status == _filterStatus).toList();
    }

    // فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((n) {
        return n.message.toLowerCase().contains(query) ||
            n.recipient.toLowerCase().contains(query) ||
            (n.subject?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الإشعارات المجدولة', icon: Icon(Icons.schedule)),
            Tab(text: 'الإشعارات الفورية', icon: Icon(Icons.notifications_active)),
          ],
        ),
      ),
      body: Column(
        children: [
          // شريط البحث والفلترة
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث في الإشعارات...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<NotificationType?>(
                        decoration: const InputDecoration(
                          labelText: 'النوع',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _filterType,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('جميع الأنواع'),
                          ),
                          ...NotificationType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(_getTypeName(type)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _filterType = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<NotificationStatus?>(
                        decoration: const InputDecoration(
                          labelText: 'الحالة',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _filterStatus,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('جميع الحالات'),
                          ),
                          ...NotificationStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusName(status)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _filterStatus = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // المحتوى
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScheduledNotificationsTab(),
                _buildInAppNotificationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledNotificationsTab() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const ListSkeletonLoader(itemCount: 5);
        }

        final filtered = _filteredNotifications;

        if (filtered.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.notifications_none,
            title: _searchQuery.isNotEmpty || _filterType != null || _filterStatus != null
                ? 'لا توجد نتائج'
                : 'لا توجد إشعارات مجدولة',
            subtitle: _searchQuery.isNotEmpty || _filterType != null || _filterStatus != null
                ? 'جرب تغيير معايير البحث أو الفلترة'
                : 'لم يتم جدولة أي إشعارات بعد',
            action: ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث'),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadNotifications,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final notification = filtered[index];
              return _buildNotificationCard(notification, provider);
            },
          ),
        );
      },
    );
  }

  Widget _buildInAppNotificationsTab() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final notifications = provider.inAppNotifications;

        if (notifications.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.notifications_off,
            title: 'لا توجد إشعارات فورية',
            subtitle: 'ستظهر الإشعارات الفورية هنا عند استلامها',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildInAppNotificationCard(notification, provider);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, NotificationProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(notification.type).withOpacity(0.1),
          child: Icon(
            _getTypeIcon(notification.type),
            color: _getTypeColor(notification.type),
          ),
        ),
        title: Text(
          notification.subject ?? notification.message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  notification.recipient,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(notification.scheduledAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(
                    _getStatusName(notification.status),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: _getStatusColor(notification.status).withOpacity(0.1),
                  labelStyle: TextStyle(color: _getStatusColor(notification.status)),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    _getTypeName(notification.type),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.grey[200],
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (notification.status == NotificationStatus.scheduled)
              PopupMenuItem(
                child: const Text('إلغاء'),
                onTap: () {
                  provider.updateNotificationStatus(
                    notification.id,
                    NotificationStatus.cancelled,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInAppNotificationCard(InAppNotification notification, NotificationProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.color.withOpacity(0.1),
          child: Icon(
            notification.icon,
            color: notification.color,
          ),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm:ss').format(notification.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            provider.removeInAppNotification(notification.id);
          },
        ),
      ),
    );
  }

  String _getTypeName(NotificationType type) {
    switch (type) {
      case NotificationType.sms:
        return 'رسالة نصية';
      case NotificationType.email:
        return 'بريد إلكتروني';
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.sms:
        return Icons.message;
      case NotificationType.email:
        return Icons.email;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.sms:
        return Colors.blue;
      case NotificationType.email:
        return Colors.green;
    }
  }

  String _getStatusName(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.scheduled:
        return 'مجدول';
      case NotificationStatus.sent:
        return 'تم الإرسال';
      case NotificationStatus.failed:
        return 'فشل';
      case NotificationStatus.cancelled:
        return 'ملغي';
    }
  }

  Color _getStatusColor(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.scheduled:
        return Colors.orange;
      case NotificationStatus.sent:
        return Colors.green;
      case NotificationStatus.failed:
        return Colors.red;
      case NotificationStatus.cancelled:
        return Colors.grey;
    }
  }
}

