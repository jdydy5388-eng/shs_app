# Script to disable firebase_core on Windows due to C++20 linking issues
# Run this after flutter pub get or flutter clean
# This script modifies Flutter-generated files to exclude Firebase

$ErrorActionPreference = "Stop"

$pluginFile = "windows\flutter\generated_plugins.cmake"
$registrantFile = "windows\flutter\generated_plugin_registrant.cc"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Disabling Firebase on Windows..." -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Cyan

# Fix generated_plugins.cmake
if (Test-Path $pluginFile) {
    Write-Host "`n[1/2] Fixing generated_plugins.cmake..." -ForegroundColor Yellow
    
    $content = Get-Content $pluginFile -Raw -Encoding UTF8
    
    # Remove firebase_core from the plugin list
    $content = $content -replace "(?m)^(\s+)firebase_core\s*$", ""
    
    # Add condition to skip firebase_core in foreach loop if not already present
    if ($content -notmatch "Skip firebase_core") {
        # Find the foreach loop and add condition
        $content = $content -replace `
            "(foreach\(plugin \$\{FLUTTER_PLUGIN_LIST\}\))",
            "`$1`n  # Skip firebase_core - C++20 linking issues on Windows`n  if(NOT plugin STREQUAL `"firebase_core`")"
        
        # Close the if condition before endforeach
        $content = $content -replace `
            "(endforeach\(plugin\))",
            "  endif()`n`$1"
    }
    
    Set-Content -Path $pluginFile -Value $content -Encoding UTF8 -NoNewline
    Write-Host "       [OK] Fixed generated_plugins.cmake" -ForegroundColor Green
} else {
    Write-Host "       [ERROR] Plugins file not found. Run 'flutter pub get' first." -ForegroundColor Red
    exit 1
}

# Fix generated_plugin_registrant.cc
if (Test-Path $registrantFile) {
    Write-Host "[2/2] Fixing generated_plugin_registrant.cc..." -ForegroundColor Yellow
    
    $content = Get-Content $registrantFile -Raw -Encoding UTF8
    
    # Comment out Firebase include if not already commented
    $firebaseInclude = '#include <firebase_core/firebase_core_plugin_c_api.h>'
    if ($content -match [regex]::Escape($firebaseInclude) -and 
        $content -notmatch "//.*firebase_core_plugin_c_api") {
        $replacement = "// Firebase disabled on Windows due to C++20 linking issues`n// $firebaseInclude"
        $content = $content -replace [regex]::Escape($firebaseInclude), $replacement
    }
    
    # Comment out Firebase registration if not already commented
    if ($content -match "FirebaseCorePluginCApiRegisterWithRegistrar" -and 
        $content -notmatch "//.*FirebaseCorePluginCApiRegisterWithRegistrar") {
        # Match the entire function call (multiline)
        $pattern = '(?s)(\s+)FirebaseCorePluginCApiRegisterWithRegistrar\(\s*registry->GetRegistrarForPlugin\("FirebaseCorePluginCApi"\)\s*\);'
        $replacement = "`$1// Firebase disabled on Windows due to C++20 linking issues`n`$1// FirebaseCorePluginCApiRegisterWithRegistrar(`n`$1//     registry->GetRegistrarForPlugin(`"FirebaseCorePluginCApi`"));"
        $content = $content -replace $pattern, $replacement
    }
    
    Set-Content -Path $registrantFile -Value $content -Encoding UTF8 -NoNewline
    Write-Host "       [OK] Fixed generated_plugin_registrant.cc" -ForegroundColor Green
} else {
    Write-Host "       [ERROR] Registrant file not found. Run 'flutter pub get' first." -ForegroundColor Red
    exit 1
}

Write-Host "`n===========================================" -ForegroundColor Cyan
Write-Host "Firebase disabled successfully!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "`nNote: Run this script after 'flutter pub get' or 'flutter clean'" -ForegroundColor Yellow
