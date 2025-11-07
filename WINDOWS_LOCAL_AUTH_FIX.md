# إصلاح مشكلة local_auth على Windows

## المشكلة
`local_auth_windows` plugin يحاول تحميل NuGet packages من الإنترنت، لكن الاتصال يفشل (timeout). هذا يمنع بناء التطبيق على Windows.

## الحل
تم تعطيل `local_auth_windows` plugin على Windows. المصادقة البيومترية معطلة على Windows فقط (تعمل على Android/iOS).

## إذا ظهرت المشكلة مرة أخرى

### الطريقة السريعة:
```powershell
.\fix_windows_plugins.ps1
```

### الطريقة اليدوية:
1. افتح `windows/flutter/generated_plugins.cmake`
2. احذف السطر الذي يحتوي على `local_auth_windows` من القائمة
3. تأكد من وجود شرط `if(NOT plugin STREQUAL "local_auth_windows")` في الحلقة

## ملاحظة
- ملف `generated_plugins.cmake` قد يعاد توليده تلقائياً عند `flutter pub get`
- إذا حدث ذلك، شغّل `.\fix_windows_plugins.ps1` مرة أخرى
- المصادقة البيومترية تعمل على Android/iOS فقط

