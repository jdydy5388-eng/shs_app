# إصلاح مشاكل البناء على Windows

## المشاكل الحالية

### 1. خطأ flutter_local_notifications_windows
**المشكلة:**
```
error C2440: 'initializing': cannot convert from 'ATL::CW2A' to 'std::basic_string<char,std::char_traits<char>,std::allocator<char>>'
```

**الحل:**
تم إصلاح المشكلة في ملف `plugin.cpp` بتغيير طريقة استخدام `CW2A`:
```cpp
// قبل
const std::string key = CW2A(item.Key, CP_UTF8);

// بعد
CW2A keyConverter(item.Key, CP_UTF8);
const std::string key = static_cast<const char*>(keyConverter);
```

### 2. أخطاء ربط Firebase C++20
**المشكلة:**
```
unresolved external symbol __std_find_trivial_8
unresolved external symbol __std_find_last_trivial_1
unresolved external symbol __std_find_first_of_trivial_1
unresolved external symbol __std_remove_8
```

**السبب:**
Firebase C++ SDK يحتاج إلى C++20 vectorized algorithms التي متوفرة فقط في:
- Visual Studio 2019 16.8+ (MSVC 19.28+)
- Visual Studio 2022 (MSVC 19.30+)

**الحلول المحاولة:**
1. ✅ إضافة إعدادات C++20 في CMakeLists.txt
2. ✅ إضافة compiler definitions و options
3. ✅ إضافة linker flags `/FORCE:MULTIPLE`

**إذا استمرت المشكلة:**
1. تأكد من تحديث Visual Studio 2022 إلى آخر إصدار
2. تأكد من تثبيت Windows 10 SDK (أحدث إصدار)
3. جرب تنظيف البناء وإعادة البناء:
   ```powershell
   Remove-Item -Recurse -Force build\windows
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

## ملاحظات
- ملفات plugins في `windows/flutter/ephemeral/.plugin_symlinks/` قد تُعاد توليدها عند `flutter pub get`
- إذا تم إعادة توليد الملفات، قد تحتاج إلى إعادة تطبيق الإصلاحات
- الأخطاء المتعلقة بـ PDB (مثل `firebase_app.pdb was not found`) هي تحذيرات فقط ولا تمنع البناء

