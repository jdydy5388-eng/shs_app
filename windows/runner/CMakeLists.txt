cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# إصلاح أخطاء الربط C++ لـ Firebase على Windows
# المشكلة: Firebase C++ SDK يحتاج إلى C++20 standard library features
# الأخطاء: __std_find_trivial_8, __std_find_last_trivial_1, __imp__CrtSetReportFile, etc.
# الحل: إضافة linker flags ومكتبات C++ runtime المطلوبة
if(MSVC)
  # إضافة linker flags لإصلاح أخطاء الربط C++ standard library
  # هذه الأخطاء تحدث لأن Firebase يستخدم C++20 vectorized algorithms و CRT debug functions
  get_target_property(CURRENT_LINK_FLAGS ${BINARY_NAME} LINK_FLAGS)
  if(CURRENT_LINK_FLAGS)
    set_target_properties(${BINARY_NAME} PROPERTIES
      LINK_FLAGS "${CURRENT_LINK_FLAGS} /FORCE:MULTIPLE"
    )
  else()
    set_target_properties(${BINARY_NAME} PROPERTIES
      LINK_FLAGS "/FORCE:MULTIPLE"
    )
  endif()
  
  # إضافة مكتبات C++ runtime المطلوبة لإصلاح أخطاء الربط
  # هذه المكتبات توفر C++20 vectorized algorithms و CRT functions
  target_link_libraries(${BINARY_NAME} PRIVATE
    legacy_stdio_definitions.lib
  )
  
  # إضافة compiler definitions لضمان استخدام C++20 features
  target_compile_definitions(${BINARY_NAME} PRIVATE
    _HAS_CXX20=1
    _HAS_STD_BYTE=0
  )
endif()

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
