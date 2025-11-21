# إعداد Firebase على Render

## المشكلة
الإشعارات لا تصل لأن السيرفر على Render لا يستطيع الوصول إلى Service Account JSON file.

## الحل

### الطريقة 1: استخدام Environment Variables (موصى به)

في Render Dashboard:

1. اذهب إلى: https://dashboard.render.com
2. اختر مشروعك: `shs-app`
3. اضغط على الخدمة (Service)
4. اضغط على "Environment" في القائمة الجانبية
5. أضف المتغيرات التالية:

```env
FIREBASE_PROJECT_ID=shs-app-6224c
FIREBASE_SERVICE_ACCOUNT_PATH=/opt/render/project/src/server/firebase-service-account.json
```

### الطريقة 2: رفع Service Account JSON File

1. في Render Dashboard → Service → Settings
2. في قسم "Build Command"، تأكد من أن Build Command ينسخ ملف Service Account:

```bash
# Build Command
cd server && dart pub get && cp firebase-service-account.json /opt/render/project/src/server/ 2>/dev/null || true
```

3. أو أضف Service Account JSON كـ Secret File في Render

### الطريقة 3: استخدام Environment Variable للـ JSON Content

1. افتح ملف `firebase-service-account.json`
2. انسخ محتواه كاملاً
3. في Render Dashboard → Environment:
   - أضف متغير جديد:
     - Key: `FIREBASE_SERVICE_ACCOUNT_JSON`
     - Value: (الصق محتوى JSON كاملاً)
4. عدّل `server/lib/config/server_config.dart` لقراءة من Environment Variable:

```dart
String? firebaseServiceAccountJson; // JSON content as string

void load() {
  // ...
  firebaseServiceAccountJson = env['FIREBASE_SERVICE_ACCOUNT_JSON'];
}
```

5. عدّل `server/lib/utils/firebase_auth_helper.dart` لاستخدام JSON من Environment Variable بدلاً من File

---

## التحقق من الإعداد

بعد إضافة Environment Variables:

1. في Render Dashboard → Service → Logs
2. ابحث عن:
   ```
   ✅ Firebase access token obtained successfully
   ```
3. إذا ظهرت رسالة خطأ:
   ```
   ❌ Neither V1 API nor Legacy API configured
   ```
   هذا يعني أن Service Account غير مُعد بشكل صحيح

---

## ملاحظات

- على Render Free Tier، قد يكون السيرفر نائماً
- أول طلب قد يستغرق وقتاً أطول لإيقاظ السيرفر
- Service Account JSON يجب أن يكون آمن ولا يُرفع على GitHub

---

## الحل السريع (للاختبار)

إذا كنت تريد اختبار الإشعارات بدون إعداد Render:

1. استخدم سيرفر محلي مؤقتاً
2. أو استخدم Firebase Console لإرسال إشعارات يدوياً

