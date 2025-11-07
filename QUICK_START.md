# دليل البدء السريع

## خطوات سريعة للبدء

### 1. تثبيت الحزم
```bash
flutter pub get
```

### 2. إعداد Firebase (مطلوب)
1. أنشئ مشروع Firebase جديد من [Firebase Console](https://console.firebase.google.com/)
2. فعّل Authentication → Email/Password
3. أنشئ Firestore Database
4. فعّل Storage
5. قم بتنزيل ملفات التكوين:
   - Android: `google-services.json` → ضعه في `android/app/`
   - iOS: `GoogleService-Info.plist` → ضعه في `ios/Runner/`
6. قم بتشغيل `flutterfire configure` أو حدث `lib/firebase_options.dart` يدوياً

### 3. تشغيل التطبيق
```bash
flutter run
```

## ملاحظات مهمة

⚠️ **يجب إعداد Firebase قبل تشغيل التطبيق**

⚠️ **للمصادقة البيومترية**: تأكد من إضافة الصلاحيات في AndroidManifest.xml و Info.plist (راجع SETUP_GUIDE.md)

⚠️ **للذكاء الاصطناعي**: أضف API Key لـ Google Gemini في `lib/services/ai_service.dart` (اختياري)

## الميزات المتوفرة

✅ تسجيل الدخول مع المصادقة البيومترية  
✅ إنشاء الوصفات الطبية الإلكترونية  
✅ التحقق من التفاعلات الدوائية  
✅ السجل الصحي الموحد  
✅ طلب وتتبع الأدوية  
✅ إدارة المخزون للصيدليات  
✅ تنبيهات الأدوية (قيد التطوير)  

## للمساعدة

راجع `SETUP_GUIDE.md` للتفاصيل الكاملة

