# ✅ إكمال إعداد Firebase - خطوة بخطوة

## ✅ ما تم إنجازه:
- ✅ قاعدة بيانات Firestore جاهزة: `(default)`
- ✅ المشروع: `shs-app-6224c`

## 📋 الخطوات المتبقية:

### 1️⃣ إعداد قواعد الأمان (Rules) - **مهم جداً**

1. في صفحة Firestore الحالية، اضغط على تبويب **"Rules"** (في الأعلى)
2. ستجد القواعد الافتراضية:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if false;
       }
     }
   }
   ```
3. **استبدل كل القواعد** بالقواعد الآمنة التالية:

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

4. اضغط **"Publish"** لحفظ القواعد

---

### 2️⃣ تفعيل Authentication (المصادقة)

1. من القائمة الجانبية، اضغط على **"Build"** → **"Authentication"**
2. اضغط على **"Get started"** (إذا لم تكن مفعلة)
3. اذهب إلى تبويب **"Sign-in method"**
4. اضغط على **"Email/Password"**
5. فعّل **"Enable"** في الأعلى
6. احفظ التغييرات

---

### 3️⃣ تفعيل Storage (التخزين)

1. من القائمة الجانبية، اضغط على **"Build"** → **"Storage"**
2. اضغط على **"Get started"**
3. اختر **"Start in test mode"** (للتطوير)
4. احفظ الموقع الافتراضي أو غيره
5. اضغط **"Done"**

#### قواعد Storage (اختياري):
بعد التفعيل، اذهب إلى **"Rules"** وأضف:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /medical_records/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

### 4️⃣ إضافة تطبيق Android - **مهم جداً**

1. اضغط على أيقونة **⚙️ Project settings** (في الأعلى بجانب "shs app")
2. انتقل لأسفل إلى قسم **"Your apps"**
3. اضغط على أيقونة **Android** ➕ (أو "Add app" → Android)
4. أدخل المعلومات:
   - **Android package name**: `com.example.shs_app`
   - **App nickname**: `SHS Android` (اختياري)
   - **Debug signing certificate SHA-1**: (اتركه فارغاً للآن)
5. اضغط **"Register app"**
6. **حمّل ملف `google-services.json`**
7. **ضع الملف في**: `android/app/google-services.json`
   - يجب أن يكون الملف في: `android/app/` وليس `android/`

---

### 5️⃣ تكوين Flutter مع Firebase

#### الطريقة السهلة (موصى بها):

```bash
# تثبيت FlutterFire CLI (مرة واحدة فقط)
dart pub global activate flutterfire_cli

# تكوين Firebase
flutterfire configure
```

عند تشغيل الأمر:
- اختر المشروع: `shs-app-6224c`
- اختر المنصات: Android (و iOS إذا كنت تطور لـ iOS)

سيتم تحديث `lib/firebase_options.dart` تلقائياً!

#### أو يدوياً:

1. افتح `lib/firebase_options.dart`
2. من Firebase Console → Project Settings → Your apps → Android
3. انسخ القيم:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `storageBucket`
4. الصقها في الملف في الأماكن المناسبة

---

### 6️⃣ إضافة Google Services Plugin (Android)

#### إذا لم يكن موجوداً:

افتح `android/app/build.gradle.kts` وتأكد من وجود:

```kotlin
plugins {
    // ... plugins الأخرى
    id("com.google.gms.google-services") apply false
}
```

وفي `android/build.gradle.kts` (ملف الـ root):

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

**ملاحظة:** `flutterfire configure` عادة يضيفها تلقائياً.

---

## ✅ التحقق من الإعداد

### اختبار المصادقة:
```bash
flutter pub get
flutter run
```

1. شغّل التطبيق
2. جرب إنشاء حساب جديد
3. تحقق من Firebase Console → Authentication → Users
4. يجب أن يظهر المستخدم الجديد!

### اختبار قاعدة البيانات:
1. بعد تسجيل الدخول، التطبيق سيحفظ بيانات المستخدم في Firestore
2. تحقق من Firebase Console → Firestore → Data
3. يجب أن ترى collection `users` مع بيانات المستخدم

---

## 📝 ملخص الخدمات المطلوبة:

✅ **Firestore Database** - جاهز  
⏳ **Authentication** - يحتاج تفعيل Email/Password  
⏳ **Storage** - يحتاج تفعيل  
⏳ **Android App** - يحتاج إضافة `google-services.json`  
⏳ **Flutter Configuration** - يحتاج `flutterfire configure`

---

## ⚠️ ملاحظات مهمة:

1. **قواعد Firestore**: لا تنسَ إضافة القواعد قبل البدء
2. **google-services.json**: يجب أن يكون في `android/app/` وليس `android/`
3. **Test Mode**: قواعد Test mode مؤقتة (تنتهي بعد 30 يوم). استخدم Production mode للإنتاج
4. **App Check**: التحذير في الأعلى اختياري للآن، يمكنك تجاهله

---

## 🎯 الترتيب الموصى به:

1. ✅ قواعد Firestore (Rules)
2. ⏳ Authentication
3. ⏳ Storage
4. ⏳ إضافة Android App + `google-services.json`
5. ⏳ `flutterfire configure`
6. ✅ اختبار التطبيق

بعد إكمال هذه الخطوات، التطبيق سيعمل بشكل كامل! 🚀

