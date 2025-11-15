import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider_local.dart';
import '../utils/auth_helper.dart';
import '../widgets/account_switch_sheet.dart';

void showFriendlyAuthError(BuildContext context, Object error) {
  final text = error.toString();
  final isAuthError = text.contains('غير مصرح') || text.contains('صلاحية') || text.contains('Unauthorized') || text.contains('403');
  final snackBar = SnackBar(
    content: Text(
      isAuthError
          ? 'لا تملك صلاحية الوصول. تأكد من تسجيل الدخول بالحساب الصحيح أو تواصل مع المسؤول.'
          : 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
    ),
    action: isAuthError
        ? SnackBarAction(
            label: 'تبديل الحساب',
            onPressed: () async {
              // افتح شيت تبديل الحساب
              if (!context.mounted) return;
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: const AccountSwitchSheet(),
                  );
                },
              );
            },
          )
        : null,
    duration: const Duration(seconds: 5),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}


