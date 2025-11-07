# حل مشكلة "Unable to find git in your PATH"

## المشكلة:
```
Error: Unable to find git in your PATH.
```

## الحلول:

### الحل 1: تثبيت Git (إذا لم يكن مثبتاً)

1. **تحميل Git:**
   - اذهب إلى: https://git-scm.com/download/win
   - حمّل النسخة المناسبة لنظامك (64-bit)
   - قم بتثبيتها

2. **أثناء التثبيت:**
   - ✅ تأكد من اختيار "Add Git to PATH"
   - ✅ أو اختر "Git from the command line and also from 3rd-party software"

3. **أعد تشغيل PowerShell** بعد التثبيت

---

### الحل 2: إضافة Git إلى PATH يدوياً (إذا كان مثبتاً)

1. **اكتشف موقع Git:**
   ```powershell
   # جرب الأماكن التالية:
   Test-Path "C:\Program Files\Git\bin\git.exe"
   Test-Path "C:\Program Files\Git\cmd\git.exe"
   Test-Path "C:\Program Files (x86)\Git\bin\git.exe"
   ```

2. **أضف Git إلى PATH:**

   **في PowerShell (مؤقت - للجلسة الحالية فقط):**
   ```powershell
   $env:PATH += ";C:\Program Files\Git\bin"
   ```
   
   **أو بشكل دائم:**
   - اضغط `Win + X` واختر "System"
   - اضغط "Advanced system settings"
   - اضغط "Environment Variables"
   - في "System variables" ابحث عن "Path"
   - اضغط "Edit"
   - اضغط "New" وأضف: `C:\Program Files\Git\bin`
   - اضغط OK في كل النوافذ
   - **أعد تشغيل PowerShell**

---

### الحل 3: استخدام Git Bash (بديل سريع)

إذا كان Git مثبتاً، يمكنك استخدام Git Bash:

1. افتح **Git Bash** (من قائمة ابدأ)
2. انتقل إلى المجلد:
   ```bash
   cd /d/shs_app/server
   ```
3. شغّل:
   ```bash
   dart pub get
   ```

---

### الحل 4: استخدام Chocolatey (للتثبيت السريع)

```powershell
# تثبيت Chocolatey (إذا لم يكن مثبتاً)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# تثبيت Git
choco install git -y
```

---

### الحل 5: تخطي Git مؤقتاً (إذا لم تكن تحتاجه)

بعض المكتبات في `pubspec.yaml` قد لا تحتاج Git. يمكنك:

1. **تعديل pubspec.yaml** لإزالة أي تبعيات من Git (لكن هذا غير موصى به)

2. **أو استخدام GitHub Desktop** (واجهة رسومية لـ Git):
   - تحميل من: https://desktop.github.com/
   - هذا سيضيف Git تلقائياً

---

## التحقق من التثبيت:

بعد إضافة Git، تحقق:

```powershell
git --version
```

يجب أن ترى شيئاً مثل:
```
git version 2.XX.X.windows.X
```

---

## بعد إصلاح Git:

```powershell
cd d:\shs_app\server
dart pub get
```

---

## ملاحظة:

إذا كنت تستخدم Dart/Flutter، قد تحتاج أيضاً إلى إعادة تشغيل IDE أو Terminal بعد إضافة Git إلى PATH.

