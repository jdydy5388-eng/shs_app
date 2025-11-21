# دليل تهيئة Firebase Messaging

## 📋 نظرة عامة

Firebase Messaging يتم تهيئته تلقائياً في التطبيق. هذا الدليل يوضح كيفية عمل التهيئة والتحقق منها.

---

## 🔧 التهيئة التلقائية

### 1. تهيئة Firebase Core (في `main.dart`)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase Core (Android, iOS, Web فقط)
  if (!Platform.isWindows) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Warning: Failed to initialize Firebase: $e');
    }
  }
  
  runApp(const MyApp());
}
```

### 2. تهيئة Firebase Messaging (في `NotificationService`)

```dart
class NotificationService {
  Future<void> initialize() async {
    // 1. تهيئة الإشعارات المحلية
    await _localNotifications.initialize(...);
    
    // 2. طلب صلاحيات الإشعارات
    await requestPermissions();
    
    // 3. إعداد Firebase Messaging
    await _setupFirebaseMessaging();
  }
}
```

### 3. إعداد Firebase Messaging (`_setupFirebaseMessaging`)

```dart
Future<void> _setupFirebaseMessaging() async {
  // تخطي على Windows
  if (Platform.isWindows) {
    return;
  }
  
  try {
    // 1. إنشاء Firebase Messaging instance
    _firebaseMessaging = FirebaseMessaging.instance;
    _isFirebaseAvailable = true;
    
    // 2. طلب الصلاحيات
    final settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // 3. الحصول على FCM Token
    final token = await _firebaseMessaging!.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }
    
    // 4. إعداد معالجات الرسائل
    FirebaseMessaging.onMessage.listen((message) {
      // معالجة الإشعارات عندما يكون التطبيق مفتوح
    });
    
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // معالجة الإشعارات عند النقر (التطبيق في الخلفية)
    });
    
    // 5. معالجة الإشعارات عند فتح التطبيق من إشعار
    final initialMessage = await _firebaseMessaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }
    
  } catch (e) {
    debugPrint('⚠️ Firebase Messaging غير متاح: $e');
  }
}
```

---

## ✅ التحقق من التهيئة

### 1. في Console Logs

ابحث عن هذه الرسائل عند تشغيل التطبيق:

```
✅ Firebase initialized successfully on android
✅ Firebase Messaging initialized successfully
✅ FCM Token: [token]
✅ تم حفظ FCM Token محلياً
```

### 2. من داخل التطبيق

1. سجّل الدخول
2. اذهب إلى: **الرئيسية** → **المراقبة** → **الإعدادات**
3. اضغط "اختبار الإشعارات"
4. يجب أن يظهر FCM Token في النافذة

---

## 🔍 استكشاف الأخطاء

### المشكلة 1: "Firebase Messaging غير متاح"

**الأسباب:**
- Firebase Core لم يتم تهيئته
- `google-services.json` غير موجود أو خاطئ
- مشكلة في الاتصال بالإنترنت

**الحل:**
1. تحقق من `android/app/google-services.json`
2. تحقق من `applicationId` في `build.gradle.kts`
3. تأكد من أن Firebase Core تم تهيئته في `main()`

### المشكلة 2: "FCM Token is null"

**الأسباب:**
- صلاحيات الإشعارات غير مُعطاة
- Firebase Messaging لم يتم تهيئته بشكل صحيح

**الحل:**
1. اذهب إلى إعدادات Android → التطبيقات → shs_app → الإشعارات
2. فعّل الإشعارات
3. أعد تشغيل التطبيق

### المشكلة 3: "Firebase permissions: denied"

**الأسباب:**
- المستخدم رفض صلاحيات الإشعارات

**الحل:**
1. اذهب إلى إعدادات Android → التطبيقات → shs_app → الإشعارات
2. فعّل الإشعارات
3. أعد تشغيل التطبيق

---

## 📱 إعدادات Android المطلوبة

### 1. google-services.json

**الموقع:** `android/app/google-services.json`

**التحقق:**
```json
{
  "project_info": {
    "project_id": "shs-app-c66a7"
  },
  "client": [{
    "client_info": {
      "android_client_info": {
        "package_name": "com.example.shs_app"
      }
    }
  }]
}
```

**ملاحظة:** `package_name` يجب أن يطابق `applicationId` في `build.gradle.kts`

### 2. build.gradle.kts

**في `android/build.gradle.kts`:**
```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

**في `android/app/build.gradle.kts`:**
```kotlin
plugins {
    id("com.google.gms.google-services")
}

android {
    defaultConfig {
        applicationId = "com.example.shs_app"
    }
}
```

### 3. minSdkVersion

**في `android/app/build.gradle.kts`:**
```kotlin
android {
    defaultConfig {
        minSdk = 21  // Firebase Messaging يتطلب Android 5.0+
    }
}
```

---

## 🔄 إعادة التهيئة يدوياً

إذا فشلت التهيئة التلقائية، يمكنك إعادة التهيئة يدوياً:

```dart
final notificationService = NotificationService();
await notificationService.initialize();
```

أو من خلال `NotificationProvider`:

```dart
final provider = NotificationProvider();
await provider.notificationService.initialize();
```

---

## 📊 حالة التهيئة

للتحقق من حالة Firebase Messaging:

```dart
final notificationService = NotificationService();
final status = notificationService.getFirebaseStatus();

print('Firebase Available: ${status['isAvailable']}');
print('Has Messaging: ${status['hasMessaging']}');
print('Platform: ${status['platform']}');
```

---

## 🎯 الخطوات التالية

بعد التأكد من أن Firebase Messaging يعمل:

1. **اختبار الإشعارات من Firebase Console**
   - اذهب إلى Firebase Console → Cloud Messaging
   - أرسل إشعار تجريبي باستخدام FCM Token

2. **إضافة Firebase Admin SDK في السيرفر**
   - لإرسال إشعارات من الكود
   - راجع `server/lib/handlers/notifications_handler.dart`

3. **إضافة منطق التنقل**
   - عند النقر على الإشعارات
   - راجع `_handleNotificationNavigation()` في `NotificationService`

---

## 📚 المراجع

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Messaging Package](https://pub.dev/packages/firebase_messaging)
- [Firebase Console](https://console.firebase.google.com/project/shs-app-c66a7)

