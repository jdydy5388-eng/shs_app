# Script to disable firebase_core on Windows due to C++20 linking issues
# Run this after flutter pub get or flutter clean

$pluginFile = "windows\flutter\generated_plugins.cmake"
$registrantFile = "windows\flutter\generated_plugin_registrant.cc"

# Fix generated_plugins.cmake
if (Test-Path $pluginFile) {
    Write-Host "Fixing Firebase plugin on Windows..." -ForegroundColor Yellow
    
    $content = Get-Content $pluginFile -Raw
    
    # Remove firebase_core from list
    $content = $content -replace "(\s+)firebase_core\s*\r?\n", ""
    
    # Add condition to skip firebase_core in loop
    if ($content -notmatch "Skip firebase_core") {
        $content = $content -replace "(foreach\(plugin \$\{FLUTTER_PLUGIN_LIST\}\))", "`$1`n  # Skip firebase_core - C++20 linking issues on Windows`n  if(NOT plugin STREQUAL `"firebase_core`")"
        $content = $content -replace "(endforeach\(plugin\))", "  endif()`n`$1"
        
        # Fix indentation for lines inside condition
        $lines = $content -split "`n"
        $newLines = @()
        $inCondition = $false
        
        foreach ($line in $lines) {
            if ($line -match "if\(NOT plugin STREQUAL") {
                $inCondition = $true
                $newLines += $line
            } elseif ($line -match "endif\(\)" -and $inCondition) {
                $inCondition = $false
                $newLines += $line
            } elseif ($inCondition -and $line -match "^\s+(add_subdirectory|target_link_libraries|list\(APPEND)") {
                $newLines += "    $line"
            } else {
                $newLines += $line
            }
        }
        
        $content = $newLines -join "`n"
    }
    
    Set-Content -Path $pluginFile -Value $content -Encoding UTF8
    Write-Host "Fixed generated_plugins.cmake" -ForegroundColor Green
} else {
    Write-Host "Plugins file not found. Run 'flutter pub get' first." -ForegroundColor Red
}

# Fix generated_plugin_registrant.cc
if (Test-Path $registrantFile) {
    Write-Host "Fixing generated_plugin_registrant.cc..." -ForegroundColor Yellow
    
    $content = Get-Content $registrantFile -Raw
    
    # Comment out Firebase include
    if ($content -match '#include <firebase_core/firebase_core_plugin_c_api.h>') {
        $content = $content -replace '#include <firebase_core/firebase_core_plugin_c_api.h>', "// Firebase disabled on Windows due to C++20 linking issues`n// #include <firebase_core/firebase_core_plugin_c_api.h>"
    }
    
    # Comment out Firebase registration - handle multiline
    if ($content -match 'FirebaseCorePluginCApiRegisterWithRegistrar') {
        # Use multiline regex to match the entire function call
        $content = $content -replace '(?s)(\s+)FirebaseCorePluginCApiRegisterWithRegistrar\(\s*registry->GetRegistrarForPlugin\("FirebaseCorePluginCApi"\)\s*\);', "`$1// Firebase disabled on Windows due to C++20 linking issues`n`$1  // FirebaseCorePluginCApiRegisterWithRegistrar(`n`$1  //     registry->GetRegistrarForPlugin(`"FirebaseCorePluginCApi`"));"
    }
    
    Set-Content -Path $registrantFile -Value $content -Encoding UTF8
    Write-Host "Fixed generated_plugin_registrant.cc" -ForegroundColor Green
}

Write-Host "Firebase plugin disabled on Windows" -ForegroundColor Green
