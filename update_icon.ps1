# سكريبت تحديث أيقونة التطبيق
# استخدم: .\update_icon.ps1 -IconPath "path\to\your\icon.png"

param(
    [Parameter(Mandatory=$true)]
    [string]$IconPath
)

Write-Host "🔄 تحديث أيقونة التطبيق..." -ForegroundColor Cyan

# التحقق من وجود الملف
if (-not (Test-Path $IconPath)) {
    Write-Host "❌ الملف غير موجود: $IconPath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ تم العثور على الملف: $IconPath" -ForegroundColor Green

Write-Host ""
Write-Host "📋 يجب تحديث الأيقونة في الأماكن التالية:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Web Icons:" -ForegroundColor Cyan
Write-Host "   - web/icons/Icon-192.png (192x192)"
Write-Host "   - web/icons/Icon-512.png (512x512)"
Write-Host "   - web/icons/Icon-maskable-192.png (192x192)"
Write-Host "   - web/icons/Icon-maskable-512.png (512x512)"
Write-Host ""
Write-Host "2. Android Icons:" -ForegroundColor Cyan
Write-Host "   - android/app/src/main/res/mipmap-mdpi/ic_launcher.png (48x48)"
Write-Host "   - android/app/src/main/res/mipmap-hdpi/ic_launcher.png (72x72)"
Write-Host "   - android/app/src/main/res/mipmap-xhdpi/ic_launcher.png (96x96)"
Write-Host "   - android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png (144x144)"
Write-Host "   - android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png (192x192)"
Write-Host ""
Write-Host "3. Windows Icon:" -ForegroundColor Cyan
Write-Host "   - windows/runner/resources/app_icon.ico (ملف ICO)"
Write-Host ""
Write-Host "💡 نصيحة: استخدم أدوات مثل:" -ForegroundColor Yellow
Write-Host "   - https://www.appicon.co/ لإنشاء جميع الأحجام"
Write-Host "   - https://convertio.co/png-ico/ لتحويل PNG إلى ICO"
Write-Host ""
Write-Host "⚠️  يجب تحديث الملفات يدوياً بعد تحويلها للأحجام المطلوبة" -ForegroundColor Red

