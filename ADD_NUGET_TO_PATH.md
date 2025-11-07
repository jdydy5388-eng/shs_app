# إضافة NuGet إلى PATH

## ✅ نعم، يجب إضافة NuGet إلى PATH!

Flutter يبحث عن NuGet في أماكن محددة. إذا كان موجوداً في مكان آخر، يجب إضافته.

---

## 🔍 الخطوة 1: ابحث عن NuGet

### في PowerShell:

```powershell
# ابحث عن NuGet في جهازك
Get-ChildItem -Path "C:\" -Recurse -Filter "nuget.exe" -ErrorAction SilentlyContinue | Select-Object -First 5 FullName
```

---

## 📁 الخطوة 2: الأماكن الموصى بها

### الخيار 1: C:\ProgramData\NuGet\ (موصى به)

```powershell
# أنشئ المجلد
New-Item -ItemType Directory -Force -Path "C:\ProgramData\NuGet"

# انسخ NuGet.exe هنا (إذا كان موجود في مكان آخر)
# Copy-Item "المسار\الحالي\nuget.exe" -Destination "C:\ProgramData\NuGet\nuget.exe"
```

### الخيار 2: إضافة إلى PATH

أضف مسار NuGet إلى متغيرات البيئة.

---

## ⚙️ الخطوة 3: إضافة NuGet إلى PATH

### الطريقة 1: عبر Environment Variables (موصى به)

1. **افتح Environment Variables**:
   - اضغط `Windows + R`
   - اكتب: `sysdm.cpl`
   - اضغط Enter
   - تبويب **Advanced** → **Environment Variables**

2. **في System variables**:
   - ابحث عن **Path**
   - اضغط **Edit**

3. **أضف مسار NuGet**:
   - اضغط **New**
   - أضف: `C:\ProgramData\NuGet`
   - (أو المسار الذي يوجد فيه NuGet.exe)

4. **OK** → **OK**

5. **أعد تشغيل Terminal/VS Code**

---

### الطريقة 2: عبر PowerShell (كمدير)

```powershell
# في PowerShell كمدير (Run as Administrator)
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\ProgramData\NuGet", [EnvironmentVariableTarget]::Machine)
```

**ثم أعد تشغيل Terminal.**

---

## ✅ الخطوة 4: التحقق

### في PowerShell:

```powershell
# تحقق من NuGet
nuget

# أو
C:\ProgramData\NuGet\nuget.exe
```

يجب أن ترى معلومات عن NuGet.

---

## 🎯 الخطوة 5: إعادة تشغيل Flutter

بعد إضافة NuGet:

```bash
# في Terminal
flutter clean
flutter pub get
flutter run
```

---

## 📋 الأماكن التي يبحث فيها Flutter عن NuGet:

1. `C:\ProgramData\NuGet\nuget.exe` ✅
2. المسارات في PATH
3. `C:\Program Files\NuGet\`
4. `C:\Program Files (x86)\NuGet\`

---

## 💡 نصيحة:

**الأفضل: ضع NuGet في `C:\ProgramData\NuGet\` وأضفه إلى PATH.**

هذا يضمن أن Flutter (وأي برنامج آخر) سيجده.

---

## 🔧 إذا استمرت المشكلة:

### 1. تحقق من المسار:

```powershell
# تحقق من وجود NuGet
Test-Path "C:\ProgramData\NuGet\nuget.exe"
```

يجب أن يرجع `True`.

### 2. تحقق من PATH:

```powershell
# تحقق من PATH
$env:PATH -split ';' | Select-String -Pattern 'NuGet'
```

يجب أن ترى `C:\ProgramData\NuGet` أو المسار الذي أضفته.

### 3. أعد تشغيل Terminal بالكامل

---

**بعد إضافة NuGet إلى PATH، Flutter سيجده تلقائياً!** ✅












