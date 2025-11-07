# إعداد التطبيق على الجوال

## معلومات مهمة

- **IP جهاز Windows (الخادم):** `192.168.43.196`
- **المنفذ:** `8080`
- **الوضع:** شبكي (network mode)

## خطوات الإعداد على الجوال

### 1. تحديث `lib/config/app_config.dart`

افتح الملف وعدّل:

```dart
/// إعدادات التطبيق
class AppConfig {
  // التبديل بين الوضع المحلي والشبكي
  static const bool useLocalMode = false; // ✅ يجب أن يكون false
  
  // إعدادات الخادم
  static const String serverBaseUrl = 'http://192.168.43.196:8080'; // ✅ IP جهاز Windows
  static const String apiBaseUrl = '$serverBaseUrl/api';
  
  static bool get isLocalMode => useLocalMode;
  static bool get isNetworkMode => !useLocalMode;
}
```

### 2. التأكد من الاتصال

- ✅ الجوال والكمبيوتر في نفس الشبكة WiFi
- ✅ الخادم يعمل على Windows
- ✅ Firewall يسمح بالاتصال على المنفذ 8080

### 3. اختبار الاتصال

1. شغّل التطبيق على الجوال
2. حاول تسجيل الدخول بحساب تم إنشاؤه على Windows
3. إذا نجح، فكل شيء يعمل بشكل صحيح!

## ملاحظات

- إذا غيرت IP جهاز Windows، يجب تحديث `serverBaseUrl` على الجوال
- يمكنك التحقق من IP Windows باستخدام `ipconfig` في PowerShell

