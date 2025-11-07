# Script to copy NuGet packages before building Flutter on Windows
# Run this script before: flutter run -d windows

$packagesDir = "build\windows\x64\packages"
$sourceDir = "D:\"

Write-Host "=== Copying NuGet packages ===" -ForegroundColor Green

# Create packages directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $packagesDir | Out-Null

# 1. Copy Microsoft.Windows.ImplementationLibrary
$wilSource = "$sourceDir\microsoft.windows.implementationlibrary.1.0.220201.1"
$wilDest = "$packagesDir\Microsoft.Windows.ImplementationLibrary.1.0.220201.1"

if (Test-Path $wilSource) {
    Write-Host "Copying Microsoft.Windows.ImplementationLibrary..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $wilDest | Out-Null
    Copy-Item -Path "$wilSource\*" -Destination $wilDest -Recurse -Force
    Write-Host "OK: Microsoft.Windows.ImplementationLibrary copied" -ForegroundColor Green
} else {
    Write-Host "WARNING: Not found: $wilSource" -ForegroundColor Red
}

# 2. Copy Microsoft.Windows.CppWinRT
$cppwinrtSource = "$sourceDir\microsoft.windows.cppwinrt.2.0.220418.1"
$cppwinrtDest = "$packagesDir\Microsoft.Windows.CppWinRT.2.0.220418.1"

if (Test-Path $cppwinrtSource) {
    Write-Host "Copying Microsoft.Windows.CppWinRT..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $cppwinrtDest | Out-Null
    Copy-Item -Path "$cppwinrtSource\*" -Destination $cppwinrtDest -Recurse -Force
    Write-Host "OK: Microsoft.Windows.CppWinRT copied" -ForegroundColor Green
} else {
    Write-Host "WARNING: Not found: $cppwinrtSource" -ForegroundColor Red
    Write-Host "Download from: https://www.nuget.org/packages/Microsoft.Windows.CppWinRT/2.0.220418.1" -ForegroundColor Yellow
}

Write-Host "`n=== Copy completed ===" -ForegroundColor Green
Write-Host "You can now run: flutter run -d windows" -ForegroundColor Cyan
