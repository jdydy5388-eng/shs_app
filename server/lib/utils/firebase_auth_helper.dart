import 'dart:io';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import '../config/server_config.dart';
import '../logger/app_logger.dart';

/// Helper class للحصول على OAuth2 access token من Service Account
class FirebaseAuthHelper {
  static String? _cachedToken;
  static DateTime? _tokenExpiry;
  
  /// الحصول على OAuth2 access token من Service Account
  static Future<String?> getAccessToken() async {
    // التحقق من وجود token صالح في cache
    if (_cachedToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
        return _cachedToken;
      }
    }
    
    try {
      final config = ServerConfig();
      final serviceAccountPath = config.firebaseServiceAccountPath;
      
      if (serviceAccountPath == null || serviceAccountPath.isEmpty) {
        AppLogger.warning('FIREBASE_SERVICE_ACCOUNT_PATH not configured');
        return null;
      }
      
      final serviceAccountFile = File(serviceAccountPath);
      if (!serviceAccountFile.existsSync()) {
        AppLogger.error('Service Account file not found: $serviceAccountPath', null);
        return null;
      }
      
      // قراءة Service Account JSON
      final serviceAccountJson = jsonDecode(
        await serviceAccountFile.readAsString(),
      ) as Map<String, dynamic>;
      
      // استخدام googleapis_auth للحصول على access token
      final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
      final client = await auth.clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );
      
      // الحصول على access token من client credentials
      final accessCredentials = client.credentials;
      final accessToken = accessCredentials.accessToken;
      
      if (accessToken != null) {
        _cachedToken = accessToken.data;
        _tokenExpiry = accessToken.expiry;
        AppLogger.info('Firebase access token obtained successfully');
      }
      
      return accessToken?.data;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get Firebase access token', e, stackTrace);
      return null;
    }
  }
  
  /// مسح cache token
  static void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
  }
}

