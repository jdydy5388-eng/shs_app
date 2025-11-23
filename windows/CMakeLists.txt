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
include(flutter/generated_plugins.cmake)

# إصلاح مشكلة flutter_local_notifications_windows
# المشكلة: CW2A يعيد ATL::CW2A وليس std::string مباشرة
# الحل: إضافة إعدادات خاصة للـ plugin
if(MSVC AND TARGET flutter_local_notifications_windows)
  # إضافة compiler options لإصلاح مشكلة CW2A
  target_compile_options(flutter_local_notifications_windows PRIVATE /Zc:__cplusplus)
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
