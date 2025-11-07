# إصلاح مشكلة Android SDK Tools

## 🚨 المشكلة:
- ADB يرى الجهاز ✅
- Flutter لا يرى الجهاز ❌
- السبب: **Android SDK command-line tools مفقودة**

---

## ✅ الحل السريع:

### الطريقة 1: عبر Android Studio (الأسهل)

1. **افتح Android Studio**
2. **Tools → SDK Manager** (أو File → Settings → Appearance & Behavior → System Settings → Android SDK)
3. **في تبويب "SDK Tools"** (أعلى الصفحة)
4. **فعّل "Android SDK Command-line Tools (latest)"**
5. **اضغط "Apply"** وانتظر حتى يكتمل التثبيت
6. **أعد تشغيل Terminal**
7. **جرب:**
   ```bash
   flutter devices
   ```

---

### الطريقة 2: تحميل يدوي (إذا لم يعمل Android Studio)

1. **حمّل Android SDK Command-line Tools:**
   - الرابط: https://developer.android.com/studio#command-line-tools-only
   - اختر "Command line tools only"
   - اختر "Windows" → "SDK Command-line Tools"

2. **استخرج الملف:**
   - استخرج الملف `.zip` إلى مجلد مؤقت
   - يجب أن ترى داخل المجلد: `cmdline-tools\bin\`

3. **انسخ المجلد:**
   - انسخ مجلد `cmdline-tools` بالكامل إلى:
   ```
   C:\Users\USER\AppData\Local\Android\sdk\cmdline-tools\
   ```

4. **أعد تسمية المجلد:**
   - يجب أن يكون اسم المجلد: `latest`
   - المسار النهائي:
   ```
   C:\Users\USER\AppData\Local\Android\sdk\cmdbox-tools\latest\bin\
   ```

5. **أعد تشغيل Terminal**
6. **جرب:**
   ```bash
   flutter doctor
   flutter devices
   ```

---

## 🔧 التحقق من الإصلاح:

```bash
# التحقق من Flutter
flutter doctor

# يجب أن ترى:
# [√] Android toolchain - develop for Android devices
```

---

## 📋 بعد الإصلاح:

```bash
# 1. التحقق من الأجهزة
flutter devices

# 2. تشغيل على الجوال
flutter run
```

---

**بعد تثبيت command-line tools، Flutter سيتعرف على جهاز Android الخاص بك!** 🚀

