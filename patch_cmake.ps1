# Script to patch CMakeLists.txt to skip NuGet download if packages exist
$cmakeFile = "windows\flutter\ephemeral\.plugin_symlinks\local_auth_windows\windows\CMakeLists.txt"

if (-not (Test-Path $cmakeFile)) {
    Write-Host "CMakeLists.txt not found. Run 'flutter pub get' first." -ForegroundColor Red
    exit 1
}

$content = Get-Content $cmakeFile -Raw

# Check if already patched
if ($content -match "Check if packages exist") {
    Write-Host "CMakeLists.txt already patched." -ForegroundColor Yellow
    exit 0
}

# Replace the WIL package installation
$wilPattern = '(?s)execute_process\(COMMAND\s+.*?Microsoft\.Windows\.ImplementationLibrary.*?FATAL_ERROR.*?\)\s*endif\(\)'
$wilReplacement = @"
# Check if package exists first
set(WIL_PACKAGE_DIR "`${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.ImplementationLibrary.`${WIL_VERSION}")
if (NOT EXISTS "`${WIL_PACKAGE_DIR}/build/native/Microsoft.Windows.ImplementationLibrary.targets")
    message("Microsoft.Windows.ImplementationLibrary not found, trying to download...")
    execute_process(COMMAND
        `${NUGET} install Microsoft.Windows.ImplementationLibrary -Version `${WIL_VERSION} -OutputDirectory `${CMAKE_BINARY_DIR}/packages
        WORKING_DIRECTORY `${CMAKE_BINARY_DIR}
        RESULT_VARIABLE ret)
    if (NOT ret EQUAL 0)
        message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.ImplementationLibrary.`${WIL_VERSION}")
    endif()
else()
    message("Using existing Microsoft.Windows.ImplementationLibrary package")
endif()
"@

$content = $content -replace $wilPattern, $wilReplacement

# Replace the CppWinRT package installation
$cppwinrtPattern = '(?s)execute_process\(COMMAND\s+.*?Microsoft\.Windows\.CppWinRT.*?FATAL_ERROR.*?\)\s*endif\(\)'
$cppwinrtReplacement = @"
# Check if package exists first
set(CPPWINRT_PACKAGE_DIR "`${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT.`${CPPWINRT_VERSION}")
if (NOT EXISTS "`${CPPWINRT_PACKAGE_DIR}/bin/cppwinrt.exe")
    message("Microsoft.Windows.CppWinRT not found, trying to download...")
    execute_process(COMMAND
        `${NUGET} install Microsoft.Windows.CppWinRT -Version `${CPPWINRT_VERSION} -OutputDirectory packages
        WORKING_DIRECTORY `${CMAKE_BINARY_DIR}
        RESULT_VARIABLE ret)
    if (NOT ret EQUAL 0)
        message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.CppWinRT.`${CPPWINRT_VERSION}")
    endif()
else()
    message("Using existing Microsoft.Windows.CppWinRT package")
endif()
"@

$content = $content -replace $cppwinrtPattern, $cppwinrtReplacement

# Save the patched file
Set-Content -Path $cmakeFile -Value $content -Encoding UTF8

Write-Host "CMakeLists.txt patched successfully!" -ForegroundColor Green

