import 'package:flutter/material.dart';

/// Banner لعرض رسائل الحالة (نجاح/تحذير/معلومات)
class StatusBanner extends StatelessWidget {
  final String message;
  final StatusBannerType type;
  final IconData? icon;
  final VoidCallback? onDismiss;

  const StatusBanner({
    super.key,
    required this.message,
    required this.type,
    this.icon,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData defaultIcon;

    switch (type) {
      case StatusBannerType.success:
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        defaultIcon = Icons.check_circle_outline;
        break;
      case StatusBannerType.warning:
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        defaultIcon = Icons.warning_amber_outlined;
        break;
      case StatusBannerType.info:
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        defaultIcon = Icons.info_outline;
        break;
      case StatusBannerType.error:
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        defaultIcon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          left: BorderSide(
            color: textColor,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon ?? defaultIcon,
            color: textColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: textColor, size: 20),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

enum StatusBannerType {
  success,
  warning,
  info,
  error,
}

