# دليل استكشاف مشكلة FCM Token على Android

## المشكلة
FCM Token لا يظهر عند اختبار الإشعارات على Android.

## خطوات الاستكشاف

### 1. تحقق من Console Logs
بعد الضغط على "اختبار الإشعارات"، افتح Console وابحث عن:

```
🔍 بدء اختبار الإشعارات...
   Platform: android
   Firebase Available: true/false
   Firebase Messaging Instance: true/false
```

**إذا كان `Firebase Available: false`:**
- Firebase Core لم يتم تهيئته بشكل صحيح
- تحقق من Console logs عند بدء التطبيق:
  ```
  ✅ Firebase initialized successfully on android
  ```
- إذا لم تظهر هذه الرسالة، هناك مشكلة في تهيئة Firebase Core

**إذا كان `Firebase Messaging Instance: false`:**
- Firebase Messaging لم يتم تهيئته
- تحقق من Console logs:
  ```
  ✅ Firebase Messaging initialized successfully
  ```

### 2. تحقق من Authorization Status
ابحث عن:
```
🔄 جاري الحصول على FCM Token...
   Authorization Status: authorized/provisional/denied
```

**إذا كان `denied`:**
- صلاحيات الإشعارات غير مُعطاة
- الحل:
  1. إعدادات Android → التطبيقات → shs_app → الإشعارات
  2. فعّل الإشعارات
  3. أعد تشغيل التطبيق

**إذا كان `authorized` أو `provisional`:**
- الصلاحيات موجودة، المشكلة في مكان آخر

### 3. تحقق من google-services.json
- الملف موجود في: `android/app/google-services.json`
- `package_name` يطابق `applicationId` في `build.gradle.kts`
- `project_id` صحيح

### 4. تحقق من Firebase Cloud Messaging API
- اذهب إلى: https://console.cloud.google.com/apis/library/firebasemessaging.googleapis.com?project=shs-app-c66a7
- تأكد من أن API مفعّل

### 5. تحقق من Firebase Console
- اذهب إلى: https://console.firebase.google.com/project/shs-app-c66a7/settings/cloudmessaging
- تأكد من أن Cloud Messaging API (V1) مفعّل

## الحلول السريعة

### الحل 1: إعادة بناء التطبيق
```bash
flutter clean
flutter pub get
flutter run -d <android_device_id>
```

### الحل 2: مسح بيانات التطبيق
1. إعدادات Android → التطبيقات → shs_app
2. اضغط "Clear Data" أو "مسح البيانات"
3. أعد تشغيل التطبيق

### الحل 3: إعادة تثبيت التطبيق
```bash
flutter uninstall
flutter install
flutter run -d <android_device_id>
```

### الحل 4: التحقق من الصلاحيات يدوياً
1. إعدادات Android → التطبيقات → shs_app → الإشعارات
2. تأكد من تفعيل الإشعارات
3. إذا كان هناك خيار "Advanced" أو "إعدادات متقدمة"، تأكد من تفعيل جميع أنواع الإشعارات

## معلومات Debug المضافة

الكود الآن يطبع معلومات تفصيلية في Console:
- Platform
- Firebase Available status
- Firebase Messaging Instance status
- Authorization Status
- Token Source (من أين تم الحصول على Token)
- Token Length
- أي أخطاء تحدث

## بعد تطبيق الحلول

1. أعد تشغيل التطبيق
2. اضغط "اختبار الإشعارات"
3. افتح Console وابحث عن الرسائل المذكورة أعلاه
4. شارك Console logs إذا استمرت المشكلة

