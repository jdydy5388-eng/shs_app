# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(shs_app LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "shs_app")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# إصلاح أخطاء الربط C++20 لـ Firebase
# المشكلة: Firebase C++ SDK يحتاج إلى C++20 vectorized algorithms
# الحل: التأكد من أن جميع الأهداف تستخدم C++20 بشكل صحيح
if(MSVC)
  # إضافة إعدادات C++20 لجميع الأهداف
  set(CMAKE_CXX_STANDARD 20)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  set(CMAKE_CXX_EXTENSIONS OFF)
  
  # إضافة compiler definitions لجميع الأهداف
  add_compile_definitions(
    _HAS_CXX20=1
    _HAS_STD_BYTE=0
    _CRT_SECURE_NO_WARNINGS
    _SILENCE_ALL_CXX20_DEPRECATION_WARNINGS=1
  )
  
  # إضافة compiler options لجميع الأهداف
  # ملاحظة: /permissive- قد يسبب مشاكل مع بعض plugins، لذا سنستخدمه بحذر
  add_compile_options(/std:c++20 /Zc:__cplusplus)
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_20)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100" /wd"4996" /FS)
  target_compile_options(${TARGET} PRIVATE /EHsc)
  # استخدام MultiThreadedDLL للتوافق مع Firebase
  set_property(TARGET ${TARGET} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
  # إضافة إعدادات خاصة لـ Firebase على Windows
  if(MSVC)
    target_compile_options(${TARGET} PRIVATE /Zc:__cplusplus)
    target_compile_options(${TARGET} PRIVATE /permissive-)
    # إصلاح أخطاء الربط C++ standard library لـ Firebase
    # استخدام C++20 standard library features
    target_compile_options(${TARGET} PRIVATE /std:c++20)
    # إضافة compiler definitions لضمان استخدام C++20 features
    target_compile_definitions(${TARGET} PRIVATE 
      _HAS_CXX20=1
      _HAS_STD_BYTE=0
      _CRT_SECURE_NO_WARNINGS
      _SILENCE_ALL_CXX20_DEPRECATION_WARNINGS=1
    )
    # إضافة linker flags لإصلاح أخطاء الربط C++20 vectorized algorithms
    # /FORCE:MULTIPLE يسمح بربط رموز متعددة (مفيد عند وجود تعارضات)
    get_target_property(CURRENT_LINK_FLAGS ${TARGET} LINK_FLAGS)
    if(CURRENT_LINK_FLAGS)
      set_target_properties(${TARGET} PROPERTIES
        LINK_FLAGS "${CURRENT_LINK_FLAGS} /FORCE:MULTIPLE"
      )
    else()
      set_target_properties(${TARGET} PROPERTIES
        LINK_FLAGS "/FORCE:MULTIPLE"
      )
    endif()
  endif()
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.

# ===================================================================
# FIREBASE DISABLE FIX - MUST BE BEFORE include()
# Modify generated files to disable Firebase before including them
# ===================================================================
# Fix generated_plugins.cmake: Remove firebase_core and add skip condition
set(PLUGINS_CMAKE "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugins.cmake")
if(EXISTS "${PLUGINS_CMAKE}")
  file(READ "${PLUGINS_CMAKE}" PLUGINS_CONTENT)
  # Remove firebase_core from list
  string(REGEX REPLACE "[\r\n][ \t]*firebase_core[\r\n]" "\n" PLUGINS_CONTENT "${PLUGINS_CONTENT}")
  # Add skip condition if not present
  if(NOT PLUGINS_CONTENT MATCHES "Skip firebase_core")
    string(REGEX REPLACE 
      "(foreach\\(plugin[^)]+\\))"
      "\\1\n  # Skip firebase_core - C++20 linking issues on Windows\n  if(NOT plugin STREQUAL \"firebase_core\")"
      PLUGINS_CONTENT "${PLUGINS_CONTENT}")
    string(REGEX REPLACE
      "(endforeach\\(plugin\\))"
      "  endif()\n\\1"
      PLUGINS_CONTENT "${PLUGINS_CONTENT}")
  endif()
  file(WRITE "${PLUGINS_CMAKE}" "${PLUGINS_CONTENT}")
endif()

# Fix generated_plugin_registrant.cc: Comment out Firebase includes
# This MUST work even if Flutter regenerates the file during build
set(REGISTRANT_CC "${CMAKE_CURRENT_SOURCE_DIR}/flutter/generated_plugin_registrant.cc")
if(EXISTS "${REGISTRANT_CC}")
  file(READ "${REGISTRANT_CC}" REGISTRANT_CONTENT)
  set(ORIGINAL_REGISTRANT "${REGISTRANT_CONTENT}")
  
  # Simple check: if file contains uncommented Firebase include, replace it
  string(FIND "${REGISTRANT_CONTENT}" "#include <firebase_core/firebase_core_plugin_c_api.h>" INCLUDE_POS)
  string(FIND "${REGISTRANT_CONTENT}" "//.*firebase_core_plugin_c_api.h" COMMENTED_CHECK)
  
  if(INCLUDE_POS GREATER_EQUAL 0)
    # Check if already commented by looking for comment pattern before it
    string(SUBSTRING "${REGISTRANT_CONTENT}" ${INCLUDE_POS} 1 CHAR_BEFORE)
    # If not commented, replace it
    if(NOT COMMENTED_CHECK GREATER_EQUAL 0)
      string(REPLACE 
        "#include <firebase_core/firebase_core_plugin_c_api.h>"
        "// Firebase disabled on Windows due to C++20 linking issues\n// #include <firebase_core/firebase_core_plugin_c_api.h>"
        REGISTRANT_CONTENT "${REGISTRANT_CONTENT}")
    endif()
  endif()
  
  # Replace Firebase registration - ALWAYS check and replace if not commented
  # This handles both single-line and multi-line patterns
  string(REGEX MATCH "FirebaseCorePluginCApiRegisterWithRegistrar" HAS_REG "${REGISTRANT_CONTENT}")
  if(HAS_REG)
    # Check if already commented - look for // before FirebaseCore
    string(REGEX MATCH "//[[:space:]]*FirebaseCorePluginCApiRegisterWithRegistrar" IS_COMMENTED "${REGISTRANT_CONTENT}")
    if(NOT IS_COMMENTED)
      # Pattern 1: Multi-line with registry->GetRegistrarForPlugin on separate line
      string(REGEX REPLACE 
        "([ \t]*)FirebaseCorePluginCApiRegisterWithRegistrar\\([^\n]*\n[ \t]*registry->GetRegistrarForPlugin\\(\"FirebaseCorePluginCApi\"\\)[^\n]*\\);"
        "\\1// Firebase disabled on Windows due to C++20 linking issues\n\\1// FirebaseCorePluginCApiRegisterWithRegistrar(\n\\1//     registry->GetRegistrarForPlugin(\"FirebaseCorePluginCApi\"));"
        REGISTRANT_CONTENT "${REGISTRANT_CONTENT}")
      # Pattern 2: Single line or compact format
      string(REGEX REPLACE 
        "([ \t]*)FirebaseCorePluginCApiRegisterWithRegistrar\\([^)]*\\);"
        "\\1// Firebase disabled on Windows due to C++20 linking issues\n\\1// FirebaseCorePluginCApiRegisterWithRegistrar(\n\\1//     registry->GetRegistrarForPlugin(\"FirebaseCorePluginCApi\"));"
        REGISTRANT_CONTENT "${REGISTRANT_CONTENT}")
    endif()
  endif()
  
  # Always write back (CMake will optimize if unchanged)
  file(WRITE "${REGISTRANT_CC}" "${REGISTRANT_CONTENT}")
endif()

# Now include the modified files
include(flutter/generated_plugins.cmake)

# Additional safety: Remove firebase_core_plugin from linking if it somehow got linked
if(TARGET firebase_core_plugin)
  set_target_properties(firebase_core_plugin PROPERTIES EXCLUDE_FROM_ALL TRUE)
  get_target_property(CURRENT_LIBS ${BINARY_NAME} LINK_LIBRARIES)
  if(CURRENT_LIBS)
    list(REMOVE_ITEM CURRENT_LIBS firebase_core_plugin)
    set_target_properties(${BINARY_NAME} PROPERTIES LINK_LIBRARIES "${CURRENT_LIBS}")
  endif()
endif()

# إصلاح مشكلة flutter_local_notifications_windows
# المشكلة 1: CW2A يعيد ATL::CW2A وليس std::string مباشرة
# المشكلة 2: C1041 - cannot open program database (PDB) - عدة عمليات CL.EXE تكتب على نفس PDB
# الحل: إضافة إعدادات خاصة للـ plugin
if(MSVC AND TARGET flutter_local_notifications_windows)
  # إضافة compiler options لإصلاح مشكلة CW2A
  target_compile_options(flutter_local_notifications_windows PRIVATE /Zc:__cplusplus)
  # إضافة /FS لإصلاح مشكلة PDB (C1041) - يسمح لعدة عمليات CL.EXE بالكتابة على نفس PDB
  target_compile_options(flutter_local_notifications_windows PRIVATE /FS)
  # إضافة compiler definitions
  target_compile_definitions(flutter_local_notifications_windows PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
