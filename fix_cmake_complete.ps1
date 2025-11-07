# Complete fix for CMakeLists.txt - removes all duplicates and fixes structure
$cmakeFile = "windows\flutter\ephemeral\.plugin_symlinks\local_auth_windows\windows\CMakeLists.txt"

if (-not (Test-Path $cmakeFile)) {
    Write-Host "File not found" -ForegroundColor Red
    exit 1
}

# Read the original file up to line 22
$lines = Get-Content $cmakeFile -Encoding UTF8
$newContent = @()

# Copy lines until line 22 (before our modifications)
for ($i = 0; $i -lt 22; $i++) {
    $newContent += $lines[$i]
}

# Add the fixed code
$newContent += ""
$newContent += "# Check if Microsoft.Windows.ImplementationLibrary exists first"
$newContent += 'set(WIL_PACKAGE_DIR "${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.ImplementationLibrary.${WIL_VERSION}")'
$newContent += 'set(WIL_TARGETS_FILE "${WIL_PACKAGE_DIR}/build/native/Microsoft.Windows.ImplementationLibrary.targets")'
$newContent += 'if(EXISTS "${WIL_TARGETS_FILE}")'
$newContent += '    message("Using existing Microsoft.Windows.ImplementationLibrary package")'
$newContent += 'else()'
$newContent += '    message("Microsoft.Windows.ImplementationLibrary not found, trying to download...")'
$newContent += '    execute_process(COMMAND'
$newContent += '        ${NUGET} install Microsoft.Windows.ImplementationLibrary -Version ${WIL_VERSION} -OutputDirectory ${CMAKE_BINARY_DIR}/packages'
$newContent += '        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}'
$newContent += '        RESULT_VARIABLE ret)'
$newContent += '    if(NOT ret EQUAL 0)'
$newContent += '        message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.ImplementationLibrary.${WIL_VERSION}")'
$newContent += '    endif()'
$newContent += 'endif()'
$newContent += ""
$newContent += "# Check if Microsoft.Windows.CppWinRT exists first"
$newContent += 'set(CPPWINRT_PACKAGE_DIR "${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}")'
$newContent += 'set(CPPWINRT_EXE "${CPPWINRT_PACKAGE_DIR}/bin/cppwinrt.exe")'
$newContent += 'if(EXISTS "${CPPWINRT_EXE}")'
$newContent += '    message("Using existing Microsoft.Windows.CppWinRT package")'
$newContent += 'else()'
$newContent += '    message("Microsoft.Windows.CppWinRT not found, trying to download...")'
$newContent += '    execute_process(COMMAND'
$newContent += '        ${NUGET} install Microsoft.Windows.CppWinRT -Version ${CPPWINRT_VERSION} -OutputDirectory packages'
$newContent += '        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}'
$newContent += '        RESULT_VARIABLE ret)'
$newContent += '    if(NOT ret EQUAL 0)'
$newContent += '        message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}")'
$newContent += '    endif()'
$newContent += 'endif()'
$newContent += ""

# Find where the rest of the file starts (after set(CPPWINRT))
$foundCppWinRT = $false
for ($i = 22; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^set\(CPPWINRT \${CMAKE_BINARY_DIR}') {
        # Found the start of the rest of the file
        for ($j = $i; $j -lt $lines.Count; $j++) {
            $newContent += $lines[$j]
        }
        $foundCppWinRT = $true
        break
    }
}

if (-not $foundCppWinRT) {
    Write-Host "Could not find continuation point" -ForegroundColor Red
    exit 1
}

# Save file
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Resolve-Path $cmakeFile), $newContent, $utf8NoBom)

Write-Host "File fixed completely!" -ForegroundColor Green

