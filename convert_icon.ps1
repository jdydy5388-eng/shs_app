# Script to convert and create app icons
# Requires: .NET Framework

$SourceImage = ".\app_icon_source.jpg"

Write-Host "Converting and creating app icons..." -ForegroundColor Cyan

if (-not (Test-Path $SourceImage)) {
    Write-Host "File not found: $SourceImage" -ForegroundColor Red
    exit 1
}

$iconsDir = ".\app_icons_temp"
if (Test-Path $iconsDir) {
    Remove-Item $iconsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null

try {
    Add-Type -AssemblyName System.Drawing
    
    $source = [System.Drawing.Image]::FromFile((Resolve-Path $SourceImage).Path)
    
    $bitmap = New-Object System.Drawing.Bitmap(1024, 1024)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.DrawImage($source, 0, 0, 1024, 1024)
    
    $baseIcon = Join-Path $iconsDir "app_icon_1024.png"
    $bitmap.Save($baseIcon, [System.Drawing.Imaging.ImageFormat]::Png)
    
    Write-Host "Created base icon (1024x1024)" -ForegroundColor Green
    
    $sizes = @(
        @{Name="Icon-192"; Size=192},
        @{Name="Icon-512"; Size=512},
        @{Name="Icon-maskable-192"; Size=192},
        @{Name="Icon-maskable-512"; Size=512},
        @{Name="ic_launcher_mdpi"; Size=48},
        @{Name="ic_launcher_hdpi"; Size=72},
        @{Name="ic_launcher_xhdpi"; Size=96},
        @{Name="ic_launcher_xxhdpi"; Size=144},
        @{Name="ic_launcher_xxxhdpi"; Size=192}
    )
    
    foreach ($item in $sizes) {
        $resized = New-Object System.Drawing.Bitmap($item.Size, $item.Size)
        $g = [System.Drawing.Graphics]::FromImage($resized)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.DrawImage($bitmap, 0, 0, $item.Size, $item.Size)
        
        $outputPath = Join-Path $iconsDir "$($item.Name).png"
        $resized.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "Created: $($item.Name).png ($($item.Size)x$($item.Size))" -ForegroundColor Green
        
        $g.Dispose()
        $resized.Dispose()
    }
    
    $graphics.Dispose()
    $bitmap.Dispose()
    $source.Dispose()
    
    Write-Host ""
    Write-Host "All icons created in: $iconsDir" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Try using online tools: https://www.appicon.co/" -ForegroundColor Yellow
    exit 1
}
