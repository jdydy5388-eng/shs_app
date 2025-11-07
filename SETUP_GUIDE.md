# دليل الإعداد والتشغيل

## خطوات الإعداد الكاملة

### 1. إعداد Firebase

#### أ. إنشاء مشروع Firebase

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. أنقر على "Add project"
3. اتبع التعليمات لإنشاء مشروع جديد
4. قم بتفعيل:
   - **Authentication** → Email/Password
   - **Firestore Database** → إنشاء قاعدة البيانات
   - **Storage** → تفعيل التخزين السحابي
   - **Cloud Messaging** → للإشعارات

#### ب. إضافة تطبيق Android

1. في Firebase Console، أنقر على أيقونة Android
2. أدخل Package Name: `com.example.shs_app` (أو اسم الحزمة الخاص بك)
3. قم بتنزيل ملف `google-services.json`
4. ضع الملف في: `android/app/`

#### ج. إضافة تطبيق iOS

1. في Firebase Console، أنقر على أيقونة iOS
2. أدخل Bundle ID: `com.example.shsApp`
3. قم بتنزيل ملف `GoogleService-Info.plist`
4. ضع الملف في: `ios/Runner/`

#### د. تحديث Firebase Options

1. قم بتشغيل الأمر:
```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```

2. أو قم بتحديث `lib/firebase_options.dart` يدوياً باستخدام البيانات من Firebase Console

### 2. إعداد المصادقة البيومترية

#### Android

أضف الصلاحيات التالية في `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

#### iOS

أضف في `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>نحتاج الوصول للتعرف على الوجه لتسجيل الدخول الآمن</string>
```

### 3. إعداد Google Gemini AI (اختياري)

1. اذهب إلى [Google AI Studio](https://makersuite.google.com/app/apikey)
2. أنشئ API Key جديد
3. افتح `lib/services/ai_service.dart`
4. استبدل `YOUR_GEMINI_API_KEY` بمفتاحك

```dart
static const String _apiKey = 'YOUR_ACTUAL_API_KEY';
```

### 4. تثبيت الحزم

```bash
flutter pub get
```

### 5. تشغيل التطبيق

```bash
# Android
flutter run

# iOS
flutter run -d ios

# محاكي معين
flutter devices  # لعرض الأجهزة المتاحة
flutter run -d <device_id>
```

## بنية قاعدة البيانات Firestore

### Collections المطلوبة

#### users
```json
{
  "id": "user_id",
  "name": "اسم المستخدم",
  "email": "email@example.com",
  "phone": "0501234567",
  "role": "patient|doctor|pharmacist",
  "profileImageUrl": "url",
  "additionalInfo": {
    // معلومات إضافية حسب الدور
  },
  "createdAt": "timestamp",
  "lastLoginAt": "timestamp"
}
```

#### prescriptions
```json
{
  "id": "prescription_id",
  "doctorId": "doctor_id",
  "doctorName": "اسم الطبيب",
  "patientId": "patient_id",
  "patientName": "اسم المريض",
  "diagnosis": "التشخيص",
  "medications": [
    {
      "id": "med_id",
      "name": "اسم الدواء",
      "dosage": "الجرعة",
      "frequency": "التكرار",
      "duration": "المدة",
      "quantity": 1
    }
  ],
  "drugInteractions": ["تحذير 1", "تحذير 2"],
  "status": "active|pending|completed",
  "createdAt": "timestamp",
  "expiresAt": "timestamp"
}
```

#### medical_records
```json
{
  "id": "record_id",
  "patientId": "patient_id",
  "doctorId": "doctor_id",
  "doctorName": "اسم الطبيب",
  "type": "diagnosis|labResult|xray|prescription",
  "title": "العنوان",
  "description": "الوصف",
  "date": "timestamp",
  "fileUrls": ["url1", "url2"],
  "createdAt": "timestamp"
}
```

#### orders
```json
{
  "id": "order_id",
  "patientId": "patient_id",
  "patientName": "اسم المريض",
  "pharmacyId": "pharmacy_id",
  "pharmacyName": "اسم الصيدلية",
  "prescriptionId": "prescription_id",
  "items": [
    {
      "medicationId": "med_id",
      "medicationName": "اسم الدواء",
      "quantity": 1,
      "price": 25.50
    }
  ],
  "status": "pending|confirmed|preparing|ready|delivered",
  "totalAmount": 25.50,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

#### inventory
```json
{
  "id": "inventory_id",
  "pharmacyId": "pharmacy_id",
  "medicationName": "اسم الدواء",
  "medicationId": "med_id",
  "quantity": 100,
  "price": 25.50,
  "manufacturer": "الشركة",
  "expiryDate": "timestamp",
  "lastUpdated": "timestamp"
}
```

## قواعد الأمان Firestore

أضف هذه القواعد في Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users: يمكن للمستخدمين قراءة/كتابة بياناتهم فقط
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // يمكن للجميع قراءة (للعثور على المرضى)
    }
    
    // Prescriptions: يمكن للأطباء والمرضى الوصول إليها
    match /prescriptions/{prescriptionId} {
      allow read: if request.auth != null && 
        (resource.data.doctorId == request.auth.uid || 
         resource.data.patientId == request.auth.uid);
      allow create: if request.auth != null && 
        request.resource.data.doctorId == request.auth.uid;
      allow update: if request.auth != null && 
        resource.data.doctorId == request.auth.uid;
    }
    
    // Medical Records: يمكن للأطباء والمرضى الوصول إليها
    match /medical_records/{recordId} {
      allow read: if request.auth != null && 
        (resource.data.doctorId == request.auth.uid || 
         resource.data.patientId == request.auth.uid);
      allow create, update: if request.auth != null;
    }
    
    // Orders: يمكن للمرضى والصيادلة الوصول إليها
    match /orders/{orderId} {
      allow read: if request.auth != null && 
        (resource.data.patientId == request.auth.uid || 
         resource.data.pharmacyId == request.auth.uid);
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        resource.data.pharmacyId == request.auth.uid;
    }
    
    // Inventory: يمكن للصيادلة فقط
    match /inventory/{inventoryId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        resource.data.pharmacyId == request.auth.uid;
    }
  }
}
```

## استكشاف الأخطاء

### مشكلة: "Firebase not initialized"
- تأكد من تحديث `firebase_options.dart` بشكل صحيح
- تأكد من وجود `google-services.json` في المكان الصحيح

### مشكلة: المصادقة البيومترية لا تعمل
- تأكد من إضافة الصلاحيات في AndroidManifest.xml و Info.plist
- اختبر على جهاز حقيقي (لا يعمل على المحاكي في بعض الأحيان)

### مشكلة: Firebase Auth لا يعمل
- تأكد من تفعيل Email/Password في Firebase Console
- تأكد من إعداد قواعد Firestore بشكل صحيح

## ملاحظات مهمة

1. **API Keys**: لا ترفع ملفات تحتوي على مفاتيح API إلى Git
2. **Firebase**: استخدم بيئة التطوير أولاً قبل الإنتاج
3. **البيانات الحساسة**: استخدم Secure Storage للمصادقة البيومترية
4. **الأمان**: راجع قواعد Firestore بعناية قبل النشر

## الخطوات التالية

- [ ] إضافة شاشة التسجيل
- [ ] تحسين واجهة المستخدم
- [ ] إضافة المزيد من التفاعلات الدوائية
- [ ] تحسين نظام الإشعارات
- [ ] إضافة الاختبارات

