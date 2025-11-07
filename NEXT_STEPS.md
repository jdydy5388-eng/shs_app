# الخطوات التالية لإعداد Firebase

## ✅ ما تم إنجازه:
- ✅ مشروع Firebase موجود: `shs-app-6224c`
- ✅ Package Name: `com.example.shs_app`

## 📋 الخطوات الفورية:

### 1. تفعيل Authentication
في Firebase Console:
- اضغط على **Build** → **Authentication** → **Get started**
- فعّل **Email/Password** من تبويب Sign-in method

### 2. إنشاء Firestore Database
- اضغط على **Build** → **Firestore Database** → **Create database**
- اختر **Test mode** (للتطوير)
- اختر موقع قاعدة البيانات

### 3. إضافة تطبيق Android
في Firebase Console:
1. اضغط على أيقونة **⚙️ Project Settings** (أعلى يسار)
2. انتقل لأسفل إلى **"Your apps"**
3. اضغط على أيقونة **Android** ➕
4. أدخل:
   - Package name: `com.example.shs_app`
5. اضغط **Register app**
6. **حمّل ملف `google-services.json`**
7. ضع الملف في: `android/app/google-services.json`

### 4. تكوين Flutter مع Firebase

#### الطريقة السهلة (موصى بها):
```bash
# تثبيت FlutterFire CLI
dart pub global activate flutterfire_cli

# تكوين Firebase
flutterfire configure
```
- اختر المشروع: `shs-app-6224c`
- اختر المنصات: Android (و iOS إذا لزم)

#### أو يدوياً:
1. افتح `lib/firebase_options.dart`
2. من Firebase Console → Project Settings → Your apps → Android
3. انسخ القيم وضَعها في الملف

### 5. إضافة Firebase plugin إلى Android

افتح `android/app/build.gradle.kts` وتأكد من وجود:

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

في `android/build.gradle.kts` (ملف الـ root، ليس app):

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

### 6. اختبار التطبيق

```bash
flutter pub get
flutter run
```

## 🎯 بعد الإعداد:

1. ✅ جرب إنشاء حساب جديد من التطبيق
2. ✅ تحقق من Firebase Console → Authentication → Users
3. ✅ تأكد من ظهور البيانات في Firestore

## 📚 ملفات المساعدة:

- `FIREBASE_SETUP_STEPS.md` - دليل شامل خطوة بخطوة
- `SETUP_GUIDE.md` - دليل الإعداد الكامل
- `QUICK_START.md` - البدء السريع

## ⚠️ ملاحظات:

- ملف `google-services.json` يجب أن يكون في `android/app/`
- لا ترفع ملفات Firebase إلى Git (تم إضافتها لـ .gitignore)
- قواعد Firestore: راجع `FIREBASE_SETUP_STEPS.md` للقواعد الآمنة

