# دليل الحصول على Firebase Server Key

## الطريقة 1: الحصول على Server Key من Firebase Console مباشرة

1. **اذهب إلى Firebase Console:**
   ```
   https://console.firebase.google.com/project/shs-app-c66a7/settings/cloudmessaging
   ```

2. **في صفحة Cloud Messaging Settings:**
   - ابحث عن قسم "Cloud Messaging API (Legacy)"
   - حتى لو كان معطلاً، قد يظهر "Server key" في نفس القسم
   - انسخه إذا كان متاحاً

---

## الطريقة 2: استخدام V1 API مع Service Account (موصى به)

### الخطوة 1: تفعيل Firebase Cloud Messaging API

1. **في Google Cloud Console:**
   - اذهب إلى: https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=shs-app-c66a7
   - أو من Firebase Console → Cloud Messaging Settings → اضغط "Manage API in Google Cloud Console"
   - اضغط "Enable"

### الخطوة 2: إنشاء Service Account

1. **في Firebase Console:**
   - اذهب إلى: Project Settings → Service Accounts
   - أو: https://console.firebase.google.com/project/shs-app-c66a7/settings/serviceaccounts/adminsdk

2. **إنشاء Private Key:**
   - اضغط "Generate new private key"
   - حمّل ملف JSON واحفظه في `server/firebase-service-account.json`

3. **إضافة إلى .env:**
   ```env
   FIREBASE_SERVICE_ACCOUNT_PATH=firebase-service-account.json
   ```

### الخطوة 3: استخدام V1 API

الكود محدث ليدعم V1 API تلقائياً.

---

## الطريقة 3: استخدام Legacy API (إذا كان متاحاً)

إذا كان Server Key متاحاً في Firebase Console:

1. انسخ Server Key
2. أضفه في `server/.env`:
   ```env
   FIREBASE_SERVER_KEY=YOUR_SERVER_KEY_HERE
   ```

---

## ملاحظات

- **Legacy API** سينتهي في 6/20/2024، لكنه يعمل الآن
- **V1 API** هو الموصى به للمستقبل
- الكود يدعم كلا الطريقتين تلقائياً

