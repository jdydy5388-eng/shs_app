# تعطيل Firebase على Windows

## المشكلة
Firebase C++ SDK يحتاج إلى C++20 vectorized algorithms التي تسبب أخطاء ربط على Windows:
```
unresolved external symbol __std_find_trivial_8
unresolved external symbol __std_find_last_trivial_1
unresolved external symbol __std_find_first_of_trivial_1
unresolved external symbol __std_remove_8
```

## الحل
تم تعطيل `firebase_core` plugin على Windows لتجنب أخطاء الربط.

## الاستخدام

### بعد `flutter pub get` أو `flutter clean`:
```powershell
.\fix_firebase_windows.ps1
```

هذا السكربت:
1. يزيل `firebase_core` من قائمة plugins
2. يضيف شرط لتخطي `firebase_core` في حلقة البناء

## ملاحظات
- Firebase معطل على Windows فقط
- Firebase يعمل بشكل طبيعي على Android/iOS/Web
- التطبيق يستخدم الإشعارات المحلية على Windows بدلاً من Firebase Cloud Messaging
- الكود Dart يتعامل مع هذا تلقائياً (راجع `lib/services/notification_service.dart`)

## إذا أردت إعادة تفعيل Firebase على Windows
1. احذف السكربت `fix_firebase_windows.ps1`
2. احذف الشرط من `windows/flutter/generated_plugins.cmake`
3. أضف `firebase_core` مرة أخرى إلى القائمة
4. **تحذير**: ستحتاج إلى حل مشكلة C++20 linking أولاً

