import '../services/server_discovery_service.dart';

/// إعدادات التطبيق
class AppConfig {
  // التبديل بين الوضع المحلي والشبكي
  static const bool useLocalMode = false; // true = محلي (SQLite), false = شبكي (REST API)
  
  // إعدادات الخادم (يستخدم فقط في الوضع الشبكي)
  // يتم اكتشاف IP الخادم تلقائياً - لا حاجة لتعديله يدوياً!
  static String? _cachedServerBaseUrl;
  
  /// الحصول على عنوان الخادم (مع اكتشاف تلقائي)
  static Future<String> get serverBaseUrl async {
    if (_cachedServerBaseUrl != null) {
      return _cachedServerBaseUrl!;
    }
    
    if (useLocalMode) {
      _cachedServerBaseUrl = 'http://localhost:8080';
      return _cachedServerBaseUrl!;
    }
    
    // اكتشاف تلقائي للخادم
    _cachedServerBaseUrl = await ServerDiscoveryService.getServerBaseUrl();
    return _cachedServerBaseUrl!;
  }
  
  /// الحصول على عنوان API (مع اكتشاف تلقائي)
  static Future<String> get apiBaseUrl async {
    final base = await serverBaseUrl;
    return '$base/api';
  }
  
  /// إعادة تعيين الكاش (لإعادة الاكتشاف)
  static void resetCache() {
    _cachedServerBaseUrl = null;
  }
  
  /// حفظ IP الخادم يدوياً (للمستخدمين المتقدمين)
  static Future<void> setServerIp(String ip, {int port = 8080}) async {
    await ServerDiscoveryService.saveServerIp(ip, port: port);
    resetCache();
  }
  
  static bool get isLocalMode => useLocalMode;
  static bool get isNetworkMode => !useLocalMode;
}
