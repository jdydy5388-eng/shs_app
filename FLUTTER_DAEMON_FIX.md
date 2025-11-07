# حل مشكلة Flutter Device Daemon Crash

## 🚨 المشكلة:
```
Flutter Device Daemon Crash
The Flutter device daemon cannot be started.
You may need to increase the maximum number of file handles available globally.
```

## ✅ الحلول (جرب بالترتيب):

---

### الحل 1: إعادة تشغيل IDE (الأسهل)

1. **أغلق Android Studio/IntelliJ IDEA بالكامل**
2. **أعد فتحه**
3. **جرب تشغيل التطبيق مرة أخرى**

---

### الحل 2: تنظيف المشروع وإعادة بناءه

في Terminal داخل IDE أو VS Code:

```bash
# تنظيف المشروع
flutter clean

# إعادة تثبيت الحزم
flutter pub get

# التحقق من Flutter
flutter doctor
```

---

### الحل 3: زيادة عدد File Handles (Windows)

هذا الحل للأخطاء المتعلقة بعدد الملفات المفتوحة:

#### أ. عبر Registry Editor (موصى به):

1. **افتح Registry Editor**:
   - اضغط `Windows + R`
   - اكتب `regedit`
   - اضغط Enter

2. **انتقل إلى**:
   ```
   HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems
   ```

3. **ابحث عن** `Windows`
   - انقر نقراً مزدوجاً على `Windows`

4. **في القيمة الحالية**، ابحث عن:
   ```
   SharedSection=1024,20480,512
   ```

5. **غيّر القيمة الثالثة** (512) إلى:
   ```
   SharedSection=1024,20480,2048
   ```

6. **احفظ وأعد تشغيل الكمبيوتر**

#### ب. عبر Command Prompt (كمدير):

```cmd
# شغّل Command Prompt كمدير (Run as Administrator)
# ثم نفّذ:

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" /v Windows /t REG_EXPAND_SZ /d "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,2048 Windows=On SubSystemType=Windows ServerDll=basesrv,1 ServerDll=winsrv:UserServerDllInitialization,3 ServerDll=sxssrv,4 ProfileControl=Off MaxRequestThreads=16" /f
```

**ثم أعد تشغيل الكمبيوتر**.

---

### الحل 4: إعادة تثبيت Flutter SDK

إذا استمرت المشكلة:

1. **احذف مجلد Flutter**:
   - افترضاً في: `C:\src\flutter`

2. **حمّل Flutter SDK من جديد**:
   - من: https://docs.flutter.dev/get-started/install/windows

3. **أعد إضافة Flutter إلى PATH**

4. **أعد تشغيل IDE**

---

### الحل 5: استخدام VS Code بدلاً من Android Studio

1. **افتح المشروع في VS Code**
2. **ثبت Flutter extension**:
   - اضغط `Ctrl+Shift+X`
   - ابحث عن "Flutter"
   - اضغط Install

3. **شغّل التطبيق من VS Code**

---

### الحل 6: التحقق من إعدادات Flutter

شغّل في Terminal:

```bash
# التحقق من Flutter
flutter doctor -v

# التحقق من الأجهزة المتاحة
flutter devices

# إعادة تشغيل Flutter daemon
flutter daemon
```

---

## 🎯 الحل السريع (جرب أولاً):

### 1. أعد تشغيل IDE:
   - أغلق Android Studio
   - افتحه من جديد

### 2. نظف المشروع:
```bash
flutter clean
flutter pub get
```

### 3. جرب تشغيل من VS Code بدلاً من Android Studio

---

## ⚠️ ملاحظات مهمة:

- **Flutter Daemon**: هو برنامج خلفي يدير الأجهزة والأدوات
- **File Handles**: عدد الملفات المفتوحة في نفس الوقت
- **Windows**: قد يحتاج زيادة الحد الافتراضي

---

## 📋 خطوات التحقق:

بعد تطبيق الحلول:

1. **افتح Terminal في IDE**
2. **شغّل**:
   ```bash
   flutter doctor
   ```
3. **تحقق من عدم وجود أخطاء**
4. **شغّل**:
   ```bash
   flutter devices
   ```
5. **يجب أن ترى الأجهزة المتاحة**

---

## 💡 نصائح إضافية:

### إذا كانت المشكلة مستمرة:

1. **تحقق من مسار Flutter**:
   ```bash
   flutter --version
   ```

2. **تحقق من PATH**:
   - تأكد أن Flutter في PATH
   - أعد تشغيل Terminal بعد إضافة PATH

3. **استخدم Command Prompt بدلاً من PowerShell**:
   - جرب تشغيل الأوامر من Command Prompt

---

## 🔄 البديل السريع:

### استخدم VS Code + Flutter Extension:

1. **افتح المشروع في VS Code**
2. **ثبت Flutter Extension**
3. **اضغط F5** لتشغيل
4. **اختر الجهاز** (Windows/Android/iOS)

VS Code غالباً يعمل بشكل أفضل مع Flutter على Windows.

---

## ✅ بعد الحل:

بعد حل المشكلة، يجب أن تعمل:
- ✅ `flutter doctor` بدون أخطاء
- ✅ `flutter devices` يظهر الأجهزة
- ✅ التطبيق يعمل بشكل طبيعي

---

**ابدأ بالحل 1 (إعادة تشغيل IDE) - إنه الأسهل والأكثر فعالية!** 🚀


