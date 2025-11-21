# إصلاح مشكلة FCM Token على Android

## المشكلة
FCM Token غير متاح على Android (`null`)

## الأسباب المحتملة

1. **Firebase Core لم يتم تهيئته بشكل صحيح**
2. **صلاحيات الإشعارات غير مُعطاة**
3. **google-services.json غير موجود أو خاطئ**
4. **Firebase Messaging لم يتم تهيئته**

## الحلول

### 1. التحقق من Console Logs

ابحث عن هذه الرسائل في Console:

```
✅ Firebase initialized successfully on android
✅ Firebase Messaging initialized successfully
✅ FCM Token: [token]
```

إذا لم تظهر هذه الرسائل، فهناك مشكلة في التهيئة.

### 2. التحقق من google-services.json

تأكد من وجود الملف في:
```
android/app/google-services.json
```

وتأكد من أن `package_name` يطابق `applicationId` في `android/app/build.gradle.kts`

### 3. إعادة بناء التطبيق

```bash
flutter clean
flutter pub get
flutter run -d <android_device_id>
```

### 4. التحقق من الصلاحيات

- اذهب إلى إعدادات Android → التطبيقات → shs_app → الإشعارات
- تأكد من تفعيل الإشعارات

### 5. إعادة تهيئة Firebase

إذا استمرت المشكلة، جرب:
1. أغلق التطبيق تماماً
2. امسح بيانات التطبيق (Settings → Apps → shs_app → Clear Data)
3. شغّل التطبيق مرة أخرى

## التحقق من الحل

بعد تطبيق الحلول:
1. شغّل التطبيق
2. سجّل الدخول
3. اذهب إلى: **الرئيسية** → **المراقبة** → **الإعدادات**
4. اضغط "اختبار الإشعارات"
5. يجب أن يظهر FCM Token في النافذة

