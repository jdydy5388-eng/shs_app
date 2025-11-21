# ✅ تم تحديث الكود لاستخدام Firebase V1 API

## ما تم إنجازه

### 1. تحديث الكود لدعم V1 API
- ✅ تحديث `server/lib/config/server_config.dart` لدعم Service Account path
- ✅ إنشاء `server/lib/utils/firebase_auth_helper.dart` للحصول على OAuth2 access token
- ✅ تحديث `server/lib/handlers/notifications_handler.dart` لاستخدام V1 API endpoint
- ✅ تحديث payload structure لـ V1 API format
- ✅ إضافة دعم Legacy API كـ fallback

### 2. تحديث التبعيات
- ✅ إضافة `googleapis_auth: ^1.4.1` و `googleapis: ^13.1.0` إلى `server/pubspec.yaml`

### 3. الأمان
- ✅ إضافة Service Account JSON إلى `.gitignore`

---

## الخطوات التالية (يجب عليك تنفيذها)

### 1. تفعيل Firebase Cloud Messaging API

1. **في Google Cloud Console:**
   - اذهب إلى: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=shs-app-c66a7
   - اضغط **"Enable"**

### 2. إنشاء Service Account

1. **في Firebase Console:**
   - اذهب إلى: **Project Settings** → **Service Accounts**
   - أو: https://console.firebase.google.com/project/shs-app-c66a7/settings/serviceaccounts/adminsdk

2. **إنشاء Private Key:**
   - اضغط **"Generate new private key"**
   - حمّل ملف JSON واحفظه في `server/firebase-service-account.json`

### 3. إعداد ملف `.env`

أضف المتغيرات التالية في `server/.env`:

```env
# Firebase V1 API Configuration
FIREBASE_SERVICE_ACCOUNT_PATH=firebase-service-account.json
FIREBASE_PROJECT_ID=shs-app-c66a7
```

### 4. اختبار الإشعارات

بعد الإعداد، يمكنك اختبار الإشعارات من:
- **Admin Screen** → **Settings** → **Test Notifications**
- أو من خلال API endpoint: `POST /api/notifications/send-fcm`

---

## كيفية عمل الكود

### V1 API (الموصى به - يتم استخدامه أولاً)

1. يقرأ Service Account JSON من المسار المحدد في `.env`
2. يستخدم `googleapis_auth` للحصول على OAuth2 access token
3. يرسل الإشعارات إلى: `https://fcm.googleapis.com/v1/projects/{project-id}/messages:send`
4. يستخدم `Authorization: Bearer <token>` header
5. يستخدم payload format الجديد:
   ```json
   {
     "message": {
       "token": "fcm-token",
       "notification": { "title": "...", "body": "..." }
     }
   }
   ```

### Legacy API (Fallback - إذا لم يكن Service Account متاحاً)

1. يستخدم Server Key من `.env`
2. يرسل الإشعارات إلى: `https://fcm.googleapis.com/fcm/send`
3. يستخدم `Authorization: key=<server-key>` header
4. يستخدم payload format القديم:
   ```json
   {
     "to": "fcm-token",
     "notification": { "title": "...", "body": "..." }
   }
   ```

---

## الفرق بين V1 API و Legacy API

| الميزة | Legacy API | V1 API |
|------|-----------|--------|
| **Endpoint** | `https://fcm.googleapis.com/fcm/send` | `https://fcm.googleapis.com/v1/projects/{project-id}/messages:send` |
| **Authorization** | `Authorization: key=<server-key>` | `Authorization: Bearer <oauth2-token>` |
| **Payload** | `{"to": "...", "notification": {...}}` | `{"message": {"token": "...", "notification": {...}}}` |
| **الأمان** | Server Key دائم | OAuth2 token ينتهي بعد ساعة |
| **التوفر** | سينتهي في 22 تموز 2024 | موصى به للمستقبل |

---

## ملاحظات مهمة

1. **Legacy API سينتهي في 22 تموز (يوليو) 2024**
   - يجب الانتقال إلى V1 API قبل هذا التاريخ

2. **OAuth2 tokens تنتهي صلاحيتها بعد ساعة**
   - الكود يقوم بتحديث token تلقائياً عند الحاجة (cache لمدة 55 دقيقة)

3. **Service Account JSON يحتوي على بيانات حساسة**
   - لا ترفعه إلى Git (تم إضافته إلى `.gitignore`)
   - استخدم متغيرات البيئة في الإنتاج

---

## استكشاف الأخطاء

### خطأ: "FIREBASE_SERVICE_ACCOUNT_PATH not configured"
**الحل:**
- أضف `FIREBASE_SERVICE_ACCOUNT_PATH=firebase-service-account.json` في `server/.env`

### خطأ: "Service Account file not found"
**الحل:**
- تأكد من أن ملف JSON موجود في `server/firebase-service-account.json`
- تحقق من المسار في `.env`

### خطأ: "Failed to get Firebase access token"
**الحل:**
- تأكد من تفعيل Firebase Cloud Messaging API في Google Cloud Console
- تحقق من صحة ملف Service Account JSON
- تأكد من أن Service Account لديه صلاحيات FCM

### خطأ: "HTTP 403: Permission denied"
**الحل:**
- تأكد من تفعيل Firebase Cloud Messaging API
- تحقق من أن Service Account لديه دور "Firebase Cloud Messaging Admin" أو "Editor"

---

## المراجع

- [Firebase Cloud Messaging HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [Google Cloud Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
- [googleapis_auth Package](https://pub.dev/packages/googleapis_auth)

---

## ✅ ملخص

الكود جاهز لاستخدام V1 API! فقط قم بـ:
1. تفعيل Firebase Cloud Messaging API
2. إنشاء Service Account وحفظ JSON
3. إضافة المتغيرات إلى `.env`
4. اختبار الإشعارات

🎉 **تم التحديث بنجاح!**

