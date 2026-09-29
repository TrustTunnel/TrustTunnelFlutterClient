# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "vpn_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "vpn_plugin_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "background_worker.cpp"
  "background_worker.h"
  "runner/platform_api.g.cpp"
  "runner/platform_api.g.h"
  "vpn_plugin.cpp"
  "vpn_plugin.h"
  "ui_thread_dispatcher.cpp"
  "ui_thread_dispatcher.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/vpn_plugin/vpn_plugin_c_api.h"
  "vpn_plugin_c_api.cpp"
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

# Dev-only lazy service install. When defined, VpnPlugin::Start() installs the
# VPN service through the elevated helper if it is missing (dev provisioning).
# Debug builds get it by default; CI can override it by setting
# the VPN_SELF_INSTALL environment variable before configuring: "1" forces it
# on, any other value forces it off.
if(DEFINED ENV{VPN_SELF_INSTALL})
  if("$ENV{VPN_SELF_INSTALL}" STREQUAL "1")
    target_compile_definitions(${PLUGIN_NAME} PRIVATE VPN_SELF_INSTALL=1)
  endif()
else()
  target_compile_definitions(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Debug>:VPN_SELF_INSTALL=1>)
endif()

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
target_link_libraries(${PLUGIN_NAME} PRIVATE Shell32 Ole32)

# === Download and use prebuilt TrustTunnelClientWindows ===
include(FetchContent)

set(TRUSTTUNNEL_CLIENT_VERSION "1.3.0-alpha.1")

# Determine the target architecture for the archive URL.
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM|aarch64")
    set(TRUSTTUNNEL_CLIENT_ARCH "aarch64")
  else()
    set(TRUSTTUNNEL_CLIENT_ARCH "x86_64")
  endif()
else()
  message(FATAL_ERROR "Unsupported architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(TRUSTTUNNEL_CLIENT_ARCHIVE_URL
  "https://$ENV{GPR_KEY}:@maven.pkg.github.com/TrustTunnel/TrustTunnelClient/com/adguard/trusttunnel/trusttunnel-client-windows/${TRUSTTUNNEL_CLIENT_VERSION}/trusttunnel-client-windows-${TRUSTTUNNEL_CLIENT_VERSION}-${TRUSTTUNNEL_CLIENT_ARCH}.zip"
)

FetchContent_Declare(
  TrustTunnelClientWindows
  URL ${TRUSTTUNNEL_CLIENT_ARCHIVE_URL}
)
FetchContent_MakeAvailable(TrustTunnelClientWindows)

# The archive ships lib/cmake/TrustTunnelClientWindows/TrustTunnelClientWindowsConfig.cmake
# Register that location so find_package() can discover it.
list(APPEND CMAKE_PREFIX_PATH "${trusttunnelclientwindows_SOURCE_DIR}")

find_package(TrustTunnelClientWindows REQUIRED)
target_link_libraries(${PLUGIN_NAME} PRIVATE TrustTunnelClientWindows::trusttunnel)

# Controls whether trusttunnel_stage_runtime strips the adapter binaries'
# Authenticode signatures. The value is read at configure time,
# so reconfigure after changing it.
if(DEFINED ENV{VPN_STRIP_SIGNATURES})
  set(TRUSTTUNNEL_STRIP_SIGNATURES "$ENV{VPN_STRIP_SIGNATURES}")
else()
  set(TRUSTTUNNEL_STRIP_SIGNATURES OFF)
endif()

trusttunnel_stage_runtime(trusttunnel_runtime TRUSTTUNNEL_RUNTIME_BINARIES
  ${TRUSTTUNNEL_STRIP_SIGNATURES})
add_dependencies(${PLUGIN_NAME} trusttunnel_runtime)

set(vpn_plugin_bundled_libraries
  ${TRUSTTUNNEL_RUNTIME_BINARIES}
  "${trusttunnelclientwindows_SOURCE_DIR}/WINTUN_LICENSE.txt"
  PARENT_SCOPE
)

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.

# Only enable test builds when building the example (which sets this variable)
# so that plugin clients aren't building the tests.
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

# Add the Google Test dependency.
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/release-1.11.0.zip
)
# Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
# Disable install commands for gtest so it doesn't end up in the bundle.
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
FetchContent_MakeAvailable(googletest)

# The plugin's C API is not very useful for unit testing, so build the sources
# directly into the test binary rather than using the DLL.
#
# We link against the real TrustTunnelClientWindows headers (for declarations)
# but provide stub implementations (test/mocks/trusttunnel_stubs.cpp) instead of
# the real library, so tests can control return values and avoid starting a
# real VPN service.
add_executable(${TEST_RUNNER}
  test/vpn_plugin_test.cpp
  test/mocks/trusttunnel_stubs.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  # Use real trusttunnel headers from the TrustTunnelClientWindows package.
  "${trusttunnelclientwindows_SOURCE_DIR}/include"
)
# Link against the Pigeon-generated API (for FlutterError, ErrorOr, etc.).
# The real TrustTunnelClientWindows::trusttunnel is NOT linked — stubs replace it.
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
target_link_libraries(${TEST_RUNNER} PRIVATE Shell32 Ole32)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
