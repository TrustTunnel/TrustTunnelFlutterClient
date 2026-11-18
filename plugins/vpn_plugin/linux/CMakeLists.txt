# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "vpn_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "vpn_plugin_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "vpn_plugin.cc"
  "linux_vpn_engine.cc"
  "platform_api.g.cc"
)

# The Pigeon-generated channel plumbing trips -Wunused-parameter and
# -Wunused-function; vpn_plugin.cc stays under the full -Wall -Werror.
set_source_files_properties(platform_api.g.cc PROPERTIES
  COMPILE_FLAGS "-Wno-unused-parameter -Wno-unused-function"
)

# === Tests ===
if (include_vpn_plugin_tests)
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

find_package(GTest REQUIRED)

add_executable(${TEST_RUNNER}
  test/linux_vpn_engine_test.cc
  linux_vpn_engine.cc
)
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
if(COMMAND apply_standard_settings)
  apply_standard_settings(${TEST_RUNNER})
endif()
target_link_libraries(${TEST_RUNNER} PRIVATE GTest::gtest_main pthread)

include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})

# Stop here if configured standalone without the Flutter app wrapper.
if(NOT COMMAND apply_standard_settings)
  return()
endif()

endif()  # include_vpn_plugin_tests

if(NOT COMMAND apply_standard_settings)
  message(FATAL_ERROR
    "vpn_plugin: configure from Flutter build or pass -Dinclude_vpn_plugin_tests=ON")
endif()

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(vpn_plugin_bundled_libraries
  ""
  PARENT_SCOPE
)
