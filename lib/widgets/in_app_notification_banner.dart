import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import 'status_banner.dart';

/// Banner لعرض الإشعارات الفورية داخل التطبيق
class InAppNotificationBanner extends StatelessWidget {
  const InAppNotificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        if (provider.inAppNotifications.isEmpty) {
          return const SizedBox.shrink();
        }

        // عرض آخر إشعار فقط
        final notification = provider.inAppNotifications.first;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: notification.color,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: notification.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.icon,
                      color: notification.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      provider.removeInAppNotification(notification.id);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (notification.onAction != null && notification.actionLabel != null)
                    TextButton(
                      onPressed: () {
                        notification.onAction?.call();
                        provider.removeInAppNotification(notification.id);
                      },
                      child: Text(notification.actionLabel!),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

