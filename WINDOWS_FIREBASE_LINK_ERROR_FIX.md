# إصلاح أخطاء الربط Firebase على Windows

## المشكلة
عند بناء التطبيق على Windows، تظهر أخطاء ربط مثل:
```
unresolved external symbol __std_find_trivial_8
unresolved external symbol __std_find_last_trivial_1
unresolved external symbol __std_find_first_of_trivial_1
unresolved external symbol __std_remove_8
```

## السبب
Firebase C++ SDK يحتاج إلى C++20 vectorized algorithms التي متوفرة فقط في:
- Visual Studio 2019 16.8 أو أحدث
- Visual Studio 2022 (جميع الإصدارات)

## الحلول

### الحل 1: تحديث Visual Studio (موصى به)
1. افتح Visual Studio Installer
2. تأكد من تثبيت:
   - Visual Studio 2019 16.8+ أو Visual Studio 2022
   - Desktop development with C++
   - Windows 10 SDK (أحدث إصدار)
3. قم بتحديث Visual Studio إذا لزم الأمر

### الحل 2: تنظيف وإعادة البناء
```powershell
# حذف مجلد البناء
Remove-Item -Recurse -Force build\windows

# إعادة البناء
flutter clean
flutter pub get
flutter run -d windows
```

### الحل 3: التحقق من إصدار Visual Studio
```powershell
# التحقق من إصدار MSVC
cl.exe
```

يجب أن يكون الإصدار 19.28 أو أحدث (لـ VS 2019) أو 19.30+ (لـ VS 2022)

### الحل 4: استخدام Visual Studio 2022
إذا كان لديك Visual Studio 2019 أقدم من 16.8، يُنصح بالترقية إلى Visual Studio 2022

### الحل 5: تعطيل Firebase مؤقتاً (للتطوير فقط)
إذا كنت تطور فقط ولا تحتاج Firebase الآن، يمكنك:
1. تعليق استيراد Firebase في `main.dart`
2. بناء التطبيق بدون Firebase
3. إعادة تفعيل Firebase لاحقاً

## ملاحظات
- الأخطاء المتعلقة بـ PDB (مثل `firebase_app.pdb was not found`) هي تحذيرات فقط ولا تمنع البناء
- الخطأ الحقيقي هو `unresolved external symbol` الذي يمنع الربط

## التحقق من الحل
بعد تطبيق الحلول، حاول البناء مرة أخرى:
```powershell
# تنظيف البناء السابق
Remove-Item -Recurse -Force build\windows -ErrorAction SilentlyContinue
flutter clean
flutter pub get
flutter run -d windows
```

## التعديلات المنفذة
تم إضافة الإعدادات التالية في `windows/CMakeLists.txt`:
- إعداد C++20 كمعيار افتراضي لجميع الأهداف
- إضافة compiler definitions المطلوبة لـ C++20
- إضافة compiler options لضمان استخدام C++20

إذا استمرت المشكلة، تأكد من:
1. استخدام Visual Studio 2019 16.8+ أو Visual Studio 2022
2. تثبيت Windows 10 SDK (أحدث إصدار)
3. تنظيف مجلد البناء وإعادة البناء
4. التحقق من أن Visual Studio محدث بالكامل

## ملاحظة مهمة
إذا استمرت المشكلة بعد كل هذه الخطوات، قد تكون المشكلة في أن Firebase C++ SDK نفسه تم بناؤه بإصدار مختلف من C++ runtime. في هذه الحالة:
- حاول تحديث Firebase C++ SDK إلى أحدث إصدار
- أو استخدم Visual Studio 2022 مع آخر تحديثات

