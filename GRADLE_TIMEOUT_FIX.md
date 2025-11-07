# إصلاح مشكلة Gradle Timeout

## 🚨 المشكلة:
```
Timeout of 120000 reached waiting for exclusive access to file: 
C:\Users\USER\.gradle\wrapper\dists\gradle-8.12-all\...\gradle-8.12-all.zip
```

---

## ✅ الحلول:

### **الحل 1: إيقاف عمليات Gradle/Java** ⭐

```powershell
# إيقاف جميع عمليات Java/Gradle
Get-Process -Name "java","gradle" -ErrorAction SilentlyContinue | Stop-Process -Force
```

---

### **الحل 2: حذف ملفات القفل (.lck)**

```powershell
$gradlePath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.12-all\ejduaidbjup3bmmkhw3rie4zb"
Remove-Item -Path "$gradlePath\*.lck" -Force
```

---

### **الحل 3: نسخ ملف Gradle من التنزيلات**

إذا كان الملف موجود في "التنزيلات":

```powershell
$gradlePath = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.12-all\ejduaidbjup3bmmkhw3rie4zb"
New-Item -ItemType Directory -Path $gradlePath -Force
Copy-Item -Path "$env:USERPROFILE\Downloads\gradle-8.12-all.zip" -Destination "$gradlePath\gradle-8.12-all.zip"
```

---

### **الحل 4: تنظيف وإعادة المحاولة**

```bash
flutter clean
flutter pub get
flutter run -d <device-id>
```

---

### **الحل 5: حذف مجلد Gradle وإعادة التنزيل**

```powershell
# احذر: هذا سيحذف جميع إصدارات Gradle
Remove-Item -Path "$env:USERPROFILE\.gradle\wrapper\dists" -Recurse -Force
```

ثم:
```bash
flutter run -d <device-id>
```

سيتم تنزيل Gradle مرة أخرى.

---

## 📋 الخطوات الموصى بها:

1. ✅ **أوقف عمليات Java/Gradle**
2. ✅ **احذف ملفات .lck**
3. ✅ **نظف المشروع: `flutter clean`**
4. ✅ **شغّل مرة أخرى: `flutter run -d <device-id>`**

---

## 💡 نصائح:

- **لا تحذف مجلد `.gradle` بالكامل** إلا إذا كنت متأكداً
- **انتظر حتى يكتمل تنزيل Gradle** قبل إعادة المحاولة
- **تأكد من عدم وجود عمليات Gradle أخرى** تعمل

---

**تم تطبيق الحلول تلقائياً!** 🚀

