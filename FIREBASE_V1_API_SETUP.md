# دليل إعداد Firebase V1 API

تم تحديث الكود لاستخدام **Firebase Cloud Messaging V1 API** بدلاً من Legacy API.

## الخطوات المطلوبة

### 1. تفعيل Firebase Cloud Messaging API

1. **في Google Cloud Console:**
   - اذهب إلى: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=shs-app-c66a7
   - أو من Firebase Console → Cloud Messaging Settings → اضغط "Manage API in Google Cloud Console"
   - اضغط **"Enable"**

### 2. إنشاء Service Account

1. **في Firebase Console:**
   - اذهب إلى: **Project Settings** → **Service Accounts**
   - أو: https://console.firebase.google.com/project/shs-app-c66a7/settings/serviceaccounts/adminsdk

2. **إنشاء Private Key:**
   - اضغط **"Generate new private key"**
   - حمّل ملف JSON واحفظه في `server/firebase-service-account.json`
   - ⚠️ **مهم**: احفظ الملف بشكل آمن ولا ترفعه إلى Git!

### 3. إعداد ملف `.env`

أضف المتغيرات التالية في `server/.env`:

```env
# Firebase V1 API Configuration
FIREBASE_SERVICE_ACCOUNT_PATH=firebase-service-account.json
FIREBASE_PROJECT_ID=shs-app-c66a7

# Legacy API (fallback - اختياري)
# FIREBASE_SERVER_KEY=YOUR_LEGACY_SERVER_KEY_HERE
```

### 4. تثبيت التبعيات

```bash
cd server
dart pub get
```

---

## كيفية عمل الكود

### V1 API (الموصى به)

الكود يحاول استخدام V1 API أولاً:
- يستخدم Service Account JSON للحصول على OAuth2 access token
- يرسل الإشعارات إلى: `https://fcm.googleapis.com/v1/projects/{project-id}/messages:send`
- يستخدم `Authorization: Bearer <token>` header

### Legacy API (Fallback)

إذا لم يكن Service Account متاحاً، يحاول استخدام Legacy API:
- يستخدم Server Key من `.env`
- يرسل الإشعارات إلى: `https://fcm.googleapis.com/fcm/send`
- يستخدم `Authorization: key=<server-key>` header

---

## الفرق بين V1 API و Legacy API

### Endpoint
- **Legacy**: `https://fcm.googleapis.com/fcm/send`
- **V1**: `https://fcm.googleapis.com/v1/projects/{project-id}/messages:send`

### Authorization
- **Legacy**: `Authorization: key=<server-key>`
- **V1**: `Authorization: Bearer <oauth2-token>`

### Payload Structure
- **Legacy**:
  ```json
  {
    "to": "fcm-token",
    "notification": { "title": "...", "body": "..." }
  }
  ```
- **V1**:
  ```json
  {
    "message": {
      "token": "fcm-token",
      "notification": { "title": "...", "body": "..." }
    }
  }
  ```

---

## الاختبار

بعد الإعداد، يمكنك اختبار الإشعارات من:
1. **Admin Screen** → **Settings** → **Test Notifications**
2. أو من خلال API endpoint: `POST /api/notifications/send-fcm`

---

## ملاحظات أمنية

1. **لا ترفع `firebase-service-account.json` إلى Git!**
   - أضفه إلى `.gitignore`
   - استخدم متغيرات البيئة في الإنتاج

2. **Legacy API سينتهي في 22 تموز (يوليو) 2024**
   - يجب الانتقال إلى V1 API قبل هذا التاريخ

3. **OAuth2 tokens تنتهي صلاحيتها بعد ساعة**
   - الكود يقوم بتحديث token تلقائياً عند الحاجة

---

## استكشاف الأخطاء

### خطأ: "FIREBASE_SERVICE_ACCOUNT_PATH not configured"
- تأكد من إضافة `FIREBASE_SERVICE_ACCOUNT_PATH` في `.env`
- تأكد من أن مسار الملف صحيح

### خطأ: "Service Account file not found"
- تأكد من أن ملف JSON موجود في المسار المحدد
- تحقق من الأذونات (permissions)

### خطأ: "Failed to get Firebase access token"
- تأكد من تفعيل Firebase Cloud Messaging API
- تحقق من صحة ملف Service Account JSON
- تأكد من أن Service Account لديه صلاحيات FCM

---

## المراجع

- [Firebase Cloud Messaging HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [Google Cloud Service Accounts](https://cloud.google.com/iam/docs/service-accounts)

