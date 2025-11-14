# دليل تحديث أيقونة التطبيق

## الملفات المطلوبة

### 1. ملف الأيقونة الأساسي
- احفظ الأيقونة كملف PNG بحجم **1024x1024** بكسل
- اسم الملف: `app_icon.png`

## الأماكن التي يجب تحديثها

### 1. Web (الويب)
ضع الأيقونة في:
- `web/icons/Icon-192.png` (192x192)
- `web/icons/Icon-512.png` (512x512)
- `web/icons/Icon-maskable-192.png` (192x192)
- `web/icons/Icon-maskable-512.png` (512x512)

### 2. Android
ضع الأيقونة في:
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

### 3. Windows
ضع الأيقونة في:
- `windows/runner/resources/app_icon.ico` (ملف ICO)

### 4. iOS
ضع الأيقونة في:
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (أحجام متعددة)

## أدوات مفيدة

### لتحويل PNG إلى ICO (Windows):
- استخدم: https://convertio.co/png-ico/
- أو: https://www.icoconverter.com/

### لإنشاء أحجام متعددة:
- استخدم: https://www.appicon.co/
- أو: https://makeappicon.com/

## بعد التحديث

1. أعد بناء التطبيق:
   ```bash
   flutter clean
   flutter pub get
   flutter build web
   flutter build apk
   flutter build windows
   ```

2. للويب: تأكد من تحديث `web/manifest.json` إذا لزم الأمر

