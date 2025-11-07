import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider_local.dart';

/// Helper للتعامل مع Authentication (الوضع المحلي فقط)
class AuthHelper {
  static AuthProviderLocal getAuthProvider(BuildContext context) {
    return Provider.of<AuthProviderLocal>(context, listen: false);
  }

  static AuthProviderLocal getAuthProviderListenable(BuildContext context) {
    return Provider.of<AuthProviderLocal>(context);
  }

  static UserModel? getCurrentUser(BuildContext context) {
    return Provider.of<AuthProviderLocal>(context, listen: false).currentUser;
  }

  static Future<void> signOut(BuildContext context) async {
    final provider = getAuthProvider(context);
    await provider.signOut();
  }
}

