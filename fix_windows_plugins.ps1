# Script to fix local_auth_windows issue on Windows
# Run this after flutter pub get or flutter clean

$pluginFile = "windows\flutter\generated_plugins.cmake"

if (Test-Path $pluginFile) {
    Write-Host "Fixing plugins file..." -ForegroundColor Yellow
    
    $lines = Get-Content $pluginFile
    $newLines = @()
    $inLoop = $false
    $loopFixed = $false
    
    foreach ($line in $lines) {
        # Remove local_auth_windows from list
        if ($line -match "^\s*local_auth_windows\s*$") {
            Write-Host "  - Removing local_auth_windows from list" -ForegroundColor Gray
            continue
        }
        
        # Add condition at start of loop
        if ($line -match "foreach\(plugin \$\{FLUTTER_PLUGIN_LIST\}\)" -and -not $loopFixed) {
            $newLines += $line
            $newLines += "  # Skip local_auth_windows - NuGet timeout issue"
            $newLines += '  if(NOT plugin STREQUAL "local_auth_windows")'
            $inLoop = $true
            $loopFixed = $true
            continue
        }
        
        # Add endif before endforeach
        if ($line -match "endforeach\(plugin\)" -and $loopFixed -and $inLoop) {
            $newLines += "  endif()"
            $inLoop = $false
        }
        
        # Add indentation if inside condition
        if ($inLoop -and $line -match "^\s+(add_subdirectory|target_link_libraries|list\(APPEND)") {
            $newLines += "    $line"
        } else {
            $newLines += $line
        }
    }
    
    Set-Content -Path $pluginFile -Value $newLines -Encoding UTF8
    Write-Host "Fixed plugins file" -ForegroundColor Green
} else {
    Write-Host "Plugins file not found" -ForegroundColor Red
}
