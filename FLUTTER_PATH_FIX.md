# إصلاح مشكلة Flutter PATH

## 🚨 المشكلة:
```
'"C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe"' is not recognized
```

## 🔍 السبب:
- Flutter غير موجود في `C:\src\flutter`
- أو PATH غير مضبوط بشكل صحيح
- أو Flutter غير مثبت بشكل كامل

---

## ✅ الحلول:

---

### الحل 1: التحقق من موقع Flutter الفعلي

#### ابحث عن Flutter في جهازك:

```powershell
# في PowerShell
Get-ChildItem -Path C:\ -Recurse -Directory -Filter "flutter" -ErrorAction SilentlyContinue | Select-Object -First 5 FullName
```

أو ابحث يدوياً في:
- `C:\flutter\`
- `C:\src\flutter\`
- `C:\Users\YourName\flutter\`
- `C:\Program Files\flutter\`

---

### الحل 2: إضافة Flutter إلى PATH

#### إذا وجدت Flutter:

1. **انسخ المسار الكامل** (مثلاً: `C:\flutter\bin`)

2. **أضف إلى PATH**:
   - اضغط `Windows + R`
   - اكتب: `sysdm.cpl`
   - اضغط Enter
   - تبويب **Advanced** → **Environment Variables**
   - في **System variables** → ابحث عن **Path**
   - اضغط **Edit**
   - اضغط **New**
   - الصق المسار (مثلاً: `C:\flutter\bin`)
   - **OK** → **OK**

3. **أعد تشغيل Terminal/VS Code**

4. **تحقق**:
   ```powershell
   flutter --version
   ```

---

### الحل 3: تثبيت Flutter من جديد

#### إذا لم تجد Flutter:

1. **حمّل Flutter SDK**:
   - من: https://docs.flutter.dev/get-started/install/windows
   - أو مباشرة: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.x.x-stable.zip

2. **استخرج الملف**:
   - استخرج إلى: `C:\flutter\` (أو أي مكان تريده)
   - **لا تضع في مجلد يحتوي على مسافات أو رموز خاصة**

3. **أضف إلى PATH** (كما في الحل 2)

4. **تحقق**:
   ```powershell
   flutter doctor
   ```

---

### الحل 4: استخدام Flutter من VS Code

#### إذا كان Flutter Extension مثبت:

1. **افتح VS Code**
2. **اضغط `Ctrl+Shift+P`**
3. **اكتب**: "Flutter: Change SDK"
4. **اختر مسار Flutter** (أو استخدم المسار الافتراضي)

---

### الحل 5: استخدام Flutter SDK المدمج في Android Studio

#### إذا كان Android Studio مثبت:

1. **افتح Android Studio**
2. **File** → **Settings** (أو `Ctrl+Alt+S`)
3. **Languages & Frameworks** → **Flutter**
4. **Flutter SDK path**: يجب أن يُظهر المسار
5. **انسخ المسار** وأضفه إلى PATH

---

## 🔍 التحقق من Flutter:

### بعد إضافة PATH:

```powershell
# تحقق من Flutter
flutter --version

# تحقق من الإعداد
flutter doctor
```

---

## ⚠️ ملاحظات مهمة:

1. **لا تضع Flutter في مجلد يحتوي مسافات**:
   - ❌ `C:\Program Files\flutter\`
   - ✅ `C:\flutter\`

2. **أعد تشغيل Terminal** بعد إضافة PATH

3. **استخدم PowerShell كمدير** لإضافة PATH

---

## 🎯 الحل السريع:

### 1. ابحث عن Flutter:
```powershell
Get-ChildItem -Path C:\ -Recurse -Directory -Filter "flutter" -ErrorAction SilentlyContinue | Select-Object -First 1 FullName
```

### 2. أضف المسار إلى PATH:
- `Windows + R` → `sysdm.cpl`
- **Advanced** → **Environment Variables**
- **Path** → **Edit** → **New**
- أضف: `C:\flutter\bin` (أو المسار الذي وجدته)

### 3. أعد تشغيل Terminal

### 4. تحقق:
```powershell
flutter --version
```

---

## 💡 إذا استمرت المشكلة:

### استخدم VS Code Flutter Extension:

1. **ثبت Flutter Extension** في VS Code
2. **اضغط `Ctrl+Shift+P`**
3. **"Flutter: New Project"** أو **"Flutter: Run"**
4. VS Code سيستخدم Flutter SDK الخاص به

---

**ابدأ بالبحث عن Flutter في جهازك أولاً!** 🔍

