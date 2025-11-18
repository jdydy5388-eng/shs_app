import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

/// Badge لعرض عدد الإشعارات غير المقروءة
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;

  const NotificationBadge({
    super.key,
    required this.child,
    this.badgeColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final count = provider.unreadCount;
        
        if (count == 0) return child;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

