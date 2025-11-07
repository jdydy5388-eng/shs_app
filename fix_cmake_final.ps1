# Final fix for CMakeLists.txt
$cmakeFile = "windows\flutter\ephemeral\.plugin_symlinks\local_auth_windows\windows\CMakeLists.txt"

if (-not (Test-Path $cmakeFile)) {
    Write-Host "File not found" -ForegroundColor Red
    exit 1
}

# Read file
$content = Get-Content $cmakeFile -Raw -Encoding UTF8

# Replace entire section with clean version
$pattern = '(?s)# Check if Microsoft\.Windows\.ImplementationLibrary exists first.*?endif\(\)'
$replacement = @"
# Check if Microsoft.Windows.ImplementationLibrary exists first
set(WIL_PACKAGE_DIR "`${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.ImplementationLibrary.`${WIL_VERSION}")
set(WIL_TARGETS_FILE "`${WIL_PACKAGE_DIR}/build/native/Microsoft.Windows.ImplementationLibrary.targets")
if(EXISTS "`${WIL_TARGETS_FILE}")
    message("Using existing Microsoft.Windows.ImplementationLibrary package")
else()
    message("Microsoft.Windows.ImplementationLibrary not found, trying to download...")
    execute_process(COMMAND
        `${NUGET} install Microsoft.Windows.ImplementationLibrary -Version `${WIL_VERSION} -OutputDirectory `${CMAKE_BINARY_DIR}/packages
        WORKING_DIRECTORY `${CMAKE_BINARY_DIR}
        RESULT_VARIABLE ret)
    if(NOT ret EQUAL 0)
        message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.ImplementationLibrary.`${WIL_VERSION}")
    endif()
endif()

# Check if Microsoft.Windows.CppWinRT exists first
set(CPPWINRT_PACKAGE_DIR "`${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT.`${CPPWINRT_VERSION}")
set(CPPWINRT_EXE "`${CPPWINRT_PACKAGE_DIR}/bin/cppwinrt.exe")
if(EXISTS "`${CPPWINRT_EXE}")
    message("Using existing Microsoft.Windows.CppWinRT package")
else()
    message("Microsoft.Windows.CppWinRT not found, trying to download...")
    execute_process(COMMAND
        `${NUGET} install Microsoft.Windows.CppWinRT -Version `${CPPWINRT_VERSION} -OutputDirectory packages
        WORKING_DIRECTORY `${CMAKE_BINARY_DIR}
        RESULT_VARIABLE ret)
    if(NOT ret EQUAL 0)
        message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.CppWinRT.`${CPPWINRT_VERSION}")
    endif()
endif()
"@

$content = $content -replace $pattern, $replacement

# Save with UTF8 without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Resolve-Path $cmakeFile), $content, $utf8NoBom)

Write-Host "Fixed!" -ForegroundColor Green

