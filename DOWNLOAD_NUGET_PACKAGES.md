# تحميل حزم NuGet المطلوبة يدوياً

## الحزم المطلوبة:

### 1. Microsoft.Windows.ImplementationLibrary ✅ (تم تحميلها)
- الرابط: https://www.nuget.org/packages/Microsoft.Windows.ImplementationLibrary/1.0.220201.1
- تم التحميل والنسخ

### 2. Microsoft.Windows.CppWinRT ⚠️ (مطلوبة)
- الرابط: https://www.nuget.org/packages/Microsoft.Windows.CppWinRT/2.0.220418.1
- اضغط "Download package" في الصفحة

## خطوات التحميل:

1. **افتح المتصفح** (Edge/Chrome)
2. **اذهب إلى الرابط أعلاه**
3. **اضغط "Download package"** (أو زر التحميل)
4. **احفظ الملف** `.nupkg` في `D:\`
5. **غيّر الامتداد** من `.nupkg` إلى `.zip`
6. **استخرج** الملف إلى `D:\microsoft.windows.cppwinrt.2.0.220418.1\`
7. **شغّل السكريبت**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File copy_nuget_packages.ps1
   ```
8. **شغّل التطبيق**:
   ```bash
   flutter run -d windows
   ```

## ملاحظة:

إذا كان المتصفح لا يعمل أيضاً، يمكنك:
- استخدام هاتفك للتحميل ثم نقل الملف عبر USB
- أو استخدام شبكة إنترنت أخرى

