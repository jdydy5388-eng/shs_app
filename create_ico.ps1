# Script to convert PNG to ICO for Windows
# Requires: .NET Framework

$SourcePng = ".\app_icons_temp\app_icon_1024.png"
$OutputIco = ".\windows\runner\resources\app_icon.ico"

if (-not (Test-Path $SourcePng)) {
    Write-Host "Source PNG not found: $SourcePng" -ForegroundColor Red
    exit 1
}

try {
    Add-Type -AssemblyName System.Drawing
    
    # Load the PNG
    $png = [System.Drawing.Image]::FromFile((Resolve-Path $SourcePng).Path)
    
    # Create ICO with multiple sizes (Windows requires this)
    $sizes = @(16, 32, 48, 64, 128, 256)
    $images = New-Object System.Collections.ArrayList
    
    foreach ($size in $sizes) {
        $resized = New-Object System.Drawing.Bitmap($size, $size)
        $g = [System.Drawing.Graphics]::FromImage($resized)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.DrawImage($png, 0, 0, $size, $size)
        $images.Add($resized) | Out-Null
        $g.Dispose()
    }
    
    # Save as ICO (simplified - Windows will use the largest size)
    $largest = $images[$images.Count - 1]
    $largest.Save($OutputIco, [System.Drawing.Imaging.ImageFormat]::Icon)
    
    Write-Host "Created ICO: $OutputIco" -ForegroundColor Green
    
    # Cleanup
    foreach ($img in $images) {
        $img.Dispose()
    }
    $png.Dispose()
    
} catch {
    Write-Host "Error creating ICO: $_" -ForegroundColor Red
    Write-Host "You can convert manually at: https://convertio.co/png-ico/" -ForegroundColor Yellow
}

