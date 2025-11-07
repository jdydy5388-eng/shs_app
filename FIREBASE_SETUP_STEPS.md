# خطوات إعداد Firebase - مشروع shs-app-6224c

## ✅ الخطوة 1: تم إنشاء المشروع
المشروع موجود: `shs-app-6224c`

## الخطوة 2: تفعيل الخدمات المطلوبة

### 2.1 Authentication (المصادقة)
1. من القائمة الجانبية، اضغط على **"Build"** → **"Authentication"**
2. اضغط على **"Get started"**
3. في تبويب **"Sign-in method"**
4. فعّل **Email/Password**:
   - اضغط على **Email/Password**
   - فعّل **Enable**
   - احفظ التغييرات

### 2.2 Firestore Database (قاعدة البيانات)
1. من القائمة الجانبية، اضغط على **"Build"** → **"Firestore Database"**
2. اضغط على **"Create database"**
3. اختر وضع بدء التشغيل:
   - **Production mode** (للتطبيق النهائي)
   - أو **Test mode** (للتطوير - أقل أماناً)
4. اختر موقع قاعدة البيانات (اختر الأقرب لمنطقتك)
5. اضغط **"Enable"**

#### إعداد قواعد الأمان لـ Firestore
بعد إنشاء قاعدة البيانات، اذهب إلى تبويب **"Rules"** وأضف هذه القواعد:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users: يمكن للمستخدمين قراءة/كتابة بياناتهم فقط
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null;
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

### 2.3 Storage (التخزين السحابي)
1. من القائمة الجانبية، اضغط على **"Build"** → **"Storage"**
2. اضغط على **"Get started"**
3. اختر وضع بدء التشغيل (نفس اختيار Firestore)
4. احفظ الموقع
5. اضغط **"Done"**

### 2.4 Cloud Messaging (الإشعارات)
1. من القائمة الجانبية، اضغط على **"Engage"** → **"Cloud Messaging"**
2. لا يحتاج إعداد خاص، سيعمل تلقائياً بعد إضافة التطبيق

## الخطوة 3: إضافة تطبيقات Android/iOS

### 3.1 إضافة تطبيق Android
1. في الصفحة الرئيسية للمشروع، اضغط على أيقونة **Android** (أو من "Project settings")
2. أدخل:
   - **Android package name**: `com.example.shs_app`
     - أو استخدم Package Name الخاص بك من `android/app/build.gradle.kts`
   - **App nickname**: `SHS Android` (اختياري)
   - **Debug signing certificate SHA-1**: (اختياري للآن)
3. اضغط **"Register app"**
4. قم بتنزيل ملف **`google-services.json`**
5. ضع الملف في: `android/app/google-services.json`
6. اتبع التعليمات لإضافة dependencies (عادة تكون جاهزة)

### 3.2 إضافة تطبيق iOS (إذا كنت تطور لـ iOS)
1. اضغط على أيقونة **iOS**
2. أدخل:
   - **iOS bundle ID**: `com.example.shsApp`
   - **App nickname**: `SHS iOS`
3. اضغط **"Register app"**
4. قم بتنزيل ملف **`GoogleService-Info.plist`**
5. ضع الملف في: `ios/Runner/GoogleService-Info.plist`

## الخطوة 4: تكوين Firebase في Flutter

### الطريقة الموصى بها: استخدام FlutterFire CLI

```bash
# تثبيت FlutterFire CLI
dart pub global activate flutterfire_cli

# تكوين Firebase
flutterfire configure
```

عند تشغيل الأمر:
- اختر المشروع: `shs-app-6224c`
- اختر المنصات: Android, iOS (إذا لزم الأمر)
- سيتم تحديث `lib/firebase_options.dart` تلقائياً

### الطريقة اليدوية: تحديث firebase_options.dart

إذا لم تستخدم CLI، افتح `lib/firebase_options.dart` واستبدل القيم بـ:

1. افتح **Project Settings** في Firebase Console
2. انتقل لأسفل إلى **"Your apps"**
3. اضغط على التطبيق (Android أو iOS)
4. انسخ القيم التالية:

- `apiKey`
- `appId`
- `messagingSenderId`
- `projectId`
- `storageBucket`

5. الصقها في `lib/firebase_options.dart`

## الخطوة 5: التحقق من التكوين

### تحقق من ملفات التكوين:
```bash
# Android
ls android/app/google-services.json

# iOS (إذا كان)
ls ios/Runner/GoogleService-Info.plist
```

### تشغيل التطبيق:
```bash
flutter pub get
flutter run
```

## الخطوة 6: اختبار المصادقة

1. شغّل التطبيق
2. جرب إنشاء حساب جديد من التطبيق
3. تحقق من Firebase Console → Authentication → Users
4. يجب أن يظهر المستخدم الجديد

## ملاحظات مهمة

⚠️ **للإنتاج**: استبدل قواعد Firestore و Storage بـ Production Mode قبل النشر

⚠️ **الأمان**: لا ترفع `google-services.json` أو `GoogleService-Info.plist` إلى Git (تم إضافتها لـ .gitignore)

⚠️ **Package Name**: تأكد أن Package Name في Firebase يطابق `android/app/build.gradle.kts`

## الدعم

إذا واجهت مشاكل:
1. راجع `SETUP_GUIDE.md` للتفاصيل
2. تحقق من Firebase Console → Project Settings → General
3. تأكد من تفعيل جميع الخدمات المطلوبة

