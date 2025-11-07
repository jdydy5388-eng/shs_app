# حل مشكلة NuGet Download Timeout

## 🚨 المشكلة:
```
Failed to connect to dist.nuget.org port 443: Timed out
Nuget.exe not found, trying to download or use cached version.
```

## 🔍 السبب:
- مشكلة في الاتصال بالإنترنت
- الجدار الناري يمنع التحميل
- NuGet غير موجود محلياً

---

## ✅ الحلول (جرب بالترتيب):

---

### الحل 1: تحميل NuGet يدوياً (الأسرع) ⭐

#### الخطوات:

1. **حمّل NuGet.exe**:
   - من: https://www.nuget.org/downloads
   - أو مباشرة: https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
   - احفظ الملف في مكان سهل

2. **أنشئ مجلد Cache**:
   ```powershell
   # في PowerShell (كمدير)
   New-Item -ItemType Directory -Force -Path "C:\ProgramData\NuGet"
   ```

3. **انسخ NuGet.exe إلى المجلد**:
   - انسخ `nuget.exe` إلى: `C:\ProgramData\NuGet\`
   - أو إلى: `C:\Program Files (x86)\NuGet\`

4. **أضف NuGet إلى PATH** (اختياري):
   - ابحث عن "Environment Variables" في Windows
   - أضف مسار NuGet إلى PATH

5. **أعد تشغيل IDE**

6. **نظف المشروع وشغّل مرة أخرى**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

### الحل 2: تحميل NuGet إلى مجلد المشروع

#### الخطوات:

1. **حمّل NuGet.exe**:
   - من: https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe
   - احفظه في: `D:\shs_app\build\windows\x64\_deps\nuget-subbuild\nuget-populate-prefix\src\`

2. **أعد تشغيل البناء**

---

### الحل 3: التحقق من الاتصال والجدار الناري

#### أ. تحقق من الاتصال:
```powershell
# في PowerShell
Test-NetConnection dist.nuget.org -Port 443
```

#### ب. تعطيل الجدار الناري مؤقتاً:
1. افتح **Windows Defender Firewall**
2. عطّل الجدار الناري مؤقتاً (للتجربة فقط)
3. جرب تحميل NuGet مرة أخرى

#### ج. إضافة استثناء في الجدار الناري:
1. **Windows Security** → **Firewall & network protection**
2. **Advanced settings**
3. **Outbound Rules** → **New Rule**
4. اسم: "NuGet Download"
5. البرنامج: `C:\Windows\System32\curl.exe` (أو CMake)
6. السماح بالاتصال

---

### الحل 4: استخدام VPN أو Proxy

إذا كان الجدار الناري في الشبكة يمنع التحميل:

1. **استخدم VPN** مؤقتاً
2. أو **كوّن Proxy** في Windows Settings

---

### الحل 5: تشغيل على Android بدلاً من Windows ⚡

**الحل البديل السريع**:

```bash
# شغّل على Android بدلاً من Windows
flutter run -d android
```

**أو**:
- افتح VS Code
- اضغط `F5`
- اختر **Android Emulator** بدلاً من Windows

---

### الحل 6: تحديث Flutter و Plugins

```bash
# تحديث Flutter
flutter upgrade

# تنظيف وإعادة بناء
flutter clean
flutter pub get

# إعادة بناء Windows
flutter build windows --release
```

---

## 🎯 الحل السريع الموصى به:

### 1. حمّل NuGet يدوياً:
👉 https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe

### 2. انسخه إلى:
```
C:\ProgramData\NuGet\nuget.exe
```

### 3. نظف المشروع:
```bash
flutter clean
flutter pub get
```

### 4. شغّل مرة أخرى

---

## 📋 خطوات تفصيلية - تثبيت NuGet يدوياً:

### الطريقة 1: عبر Chocolatey (إذا كان مثبت):

```powershell
# في PowerShell كمدير
choco install nuget.commandline
```

### الطريقة 2: تثبيت يدوي:

1. **حمّل NuGet**:
   - https://www.nuget.org/downloads
   - اختر "Command Line Tool"

2. **انسخ nuget.exe** إلى:
   ```
   C:\ProgramData\NuGet\nuget.exe
   ```

3. **أضف إلى PATH**:
   - ابحث عن "Environment Variables"
   - أضف: `C:\ProgramData\NuGet`

4. **أعد تشغيل Terminal**

---

## ⚡ الحل البديل الفوري:

### شغّل على Android:

إذا كان لديك محاكي Android:

```bash
# شغّل على Android
flutter run -d android
```

**أو**:
- افتح VS Code
- اضغط `Ctrl+Shift+P`
- اكتب: "Flutter: Select Device"
- اختر Android Emulator

---

## 🔧 التحقق من التثبيت:

بعد تثبيت NuGet:

```powershell
# في PowerShell
nuget
```

يجب أن ترى إصدار NuGet.

---

## ✅ بعد الحل:

بعد حل المشكلة:

1. ✅ NuGet سيُستخدم محلياً بدلاً من التحميل
2. ✅ البناء سيكتمل بنجاح
3. ✅ التطبيق سيعمل على Windows

---

## 💡 نصائح:

- **NuGet**: مطلوب لإدارة الحزم في Windows
- **التحميل التلقائي**: قد يفشل بسبب الجدار الناري
- **الحل اليدوي**: أكثر موثوقية

---

**جرب الحل 1 أولاً (تحميل NuGet يدوياً) - إنه الأسرع والأكثر فعالية!** 🚀

