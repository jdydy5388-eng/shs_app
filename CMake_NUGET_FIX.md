# حل مشكلة CMake NuGet - وضع NuGet في المسار المطلوب

## 🚨 المشكلة:
CMake يحاول تحميل NuGet إلى مسار محدد:
```
D:/shs_app/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix/src/nuget.exe
```

CMake لا يبحث عن NuGet في PATH، بل يريد الملف في هذا المسار بالضبط.

---

## ✅ الحل:

### تم نسخ NuGet إلى المسار المطلوب:

```powershell
# تم تنفيذ:
Copy-Item "C:\ProgramData\NuGet\nuget.exe" -Destination "D:\shs_app\build\windows\x64\_deps\nuget-subbuild\nuget-populate-prefix\src\nuget.exe"
```

---

## 🔄 الخطوات التالية:

### 1. نظف المشروع:

```bash
flutter clean
```

### 2. أعد بناء المشروع:

```bash
flutter pub get
flutter run
```

---

## ⚠️ ملاحظة مهمة:

**هذا الحل مؤقت** - إذا قمت بـ `flutter clean`، سيحذف المجلد ويحتاج إعادة النسخ.

---

## 🎯 الحل الدائم:

### الخيار 1: إنشاء Script لنسخ NuGet تلقائياً

أنشئ ملف `copy_nuget.ps1`:

```powershell
# copy_nuget.ps1
$nugetPath = "D:\shs_app\build\windows\x64\_deps\nuget-subbuild\nuget-populate-prefix\src"
New-Item -ItemType Directory -Force -Path $nugetPath | Out-Null
Copy-Item "C:\ProgramData\NuGet\nuget.exe" -Destination "$nugetPath\nuget.exe" -Force
Write-Host "NuGet copied successfully!"
```

شغّله قبل `flutter run`:
```bash
powershell -ExecutionPolicy Bypass -File copy_nuget.ps1
flutter run
```

---

### الخيار 2: استخدام Android بدلاً من Windows (الأسهل) ⭐

**تجاوز كل هذه المشاكل:**

```bash
flutter run -d android
```

أو من VS Code: اضغط `F5` → اختر Android

---

## ✅ التحقق:

بعد نسخ NuGet، CMake يجب أن يجده ويعمل البناء.

---

**جرب `flutter clean` ثم `flutter run` مرة أخرى!** 🚀












