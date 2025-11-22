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
        AppLogger.info('✅ Using cached Firebase access token');
        return _cachedToken;
      } else {
        AppLogger.info('⚠️ Cached token expired, getting new token');
      }
    }
    
    try {
      AppLogger.info('🔄 Getting Firebase OAuth2 access token...');
      final config = ServerConfig();
      Map<String, dynamic> serviceAccountJson;
      
      // محاولة قراءة من Environment Variable أولاً (لـ Render)
      if (config.firebaseServiceAccountJson != null && config.firebaseServiceAccountJson!.isNotEmpty) {
        AppLogger.info('   Reading Service Account from environment variable');
        AppLogger.info('   JSON length: ${config.firebaseServiceAccountJson!.length} chars');
        try {
          serviceAccountJson = jsonDecode(config.firebaseServiceAccountJson!) as Map<String, dynamic>;
          AppLogger.info('   ✅ Successfully parsed Service Account JSON');
          AppLogger.info('   Project ID from JSON: ${serviceAccountJson['project_id'] ?? "NOT FOUND"}');
        } catch (e) {
          AppLogger.error('❌ Failed to parse Service Account JSON from environment variable', e);
          return null;
        }
      } else {
        // محاولة قراءة من File
        final serviceAccountPath = config.firebaseServiceAccountPath;
        
        if (serviceAccountPath == null || serviceAccountPath.isEmpty) {
          AppLogger.warning('⚠️ FIREBASE_SERVICE_ACCOUNT_PATH not configured');
          AppLogger.warning('   Please configure FIREBASE_SERVICE_ACCOUNT_JSON in environment variables');
          return null;
        }
        
        final serviceAccountFile = File(serviceAccountPath);
        if (!serviceAccountFile.existsSync()) {
          AppLogger.error('❌ Service Account file not found: $serviceAccountPath', null);
          AppLogger.error('   Please configure FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON', null);
          return null;
        }
        
        AppLogger.info('   Reading Service Account from file: $serviceAccountPath');
        // قراءة Service Account JSON
        serviceAccountJson = jsonDecode(
          await serviceAccountFile.readAsString(),
        ) as Map<String, dynamic>;
        AppLogger.info('   ✅ Successfully read Service Account from file');
      }
      
      // استخدام googleapis_auth للحصول على access token
      AppLogger.info('   Creating Service Account credentials...');
      final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
      AppLogger.info('   Requesting OAuth2 access token...');
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
        AppLogger.info('✅ Firebase access token obtained successfully');
        AppLogger.info('   Token length: ${accessToken.data.length} chars');
        AppLogger.info('   Token expires at: ${accessToken.expiry}');
      } else {
        AppLogger.error('❌ Access token is null after authentication', null);
      }
      
      return accessToken?.data;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Failed to get Firebase access token', e, stackTrace);
      return null;
    }
  }
  
  /// مسح cache token
  static void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
  }
}

