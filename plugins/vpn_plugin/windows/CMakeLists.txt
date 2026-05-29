# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.24)

# Project-level configuration.
set(PROJECT_NAME "vpn_plugin")
project(${PROJECT_NAME} LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)

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

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
target_link_libraries(${PLUGIN_NAME} PRIVATE Shell32 Ole32)

# === Download and use prebuilt TrustTunnelClientWindows ===
include(FetchContent)

set(TRUSTTUNNEL_CLIENT_VERSION "1.1.5")

# Determine the target architecture for the archive URL.
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM|aarch64")
    set(TRUSTTUNNEL_CLIENT_ARCH "arm64")
  else()
    set(TRUSTTUNNEL_CLIENT_ARCH "amd64")
  endif()
else()
  message(FATAL_ERROR "Unsupported architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(TRUSTTUNNEL_CLIENT_ARCHIVE_URL
  "https://$ENV{GPR_KEY}:@maven.pkg.github.com/TrustTunnel/TrustTunnelClient/com/adguard/trusttunnel/trusttunnel-client-windows/${TRUSTTUNNEL_CLIENT_VERSION}/TrustTunnelClient-windows-${TRUSTTUNNEL_CLIENT_ARCH}-${TRUSTTUNNEL_CLIENT_VERSION}.zip"
  CACHE STRING "URL to the TrustTunnelClientWindows prebuilt archive"
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
target_link_libraries(${PLUGIN_NAME} PRIVATE TrustTunnelClientWindows::vpn_easy)

# --- Bundle vpn_easy_service.exe and wintun.dll ---
# Both are shipped inside the prebuilt archive's bin/ directory.
set(_TT_BIN_DIR "${trusttunnelclientwindows_SOURCE_DIR}/bin")

set(VPN_SERVICE_EXE "${_TT_BIN_DIR}/vpn_easy_service.exe")
if(NOT EXISTS "${VPN_SERVICE_EXE}")
  message(FATAL_ERROR "vpn_easy_service.exe not found at ${VPN_SERVICE_EXE}")
endif()

set(VPN_EASY_DLL "${_TT_BIN_DIR}/vpn_easy.dll")
if(NOT EXISTS "${VPN_EASY_DLL}")
  message(FATAL_ERROR "vpn_easy.dll not found at ${VPN_EASY_DLL}")
endif()

set(WINTUN_DLL "${_TT_BIN_DIR}/wintun.dll")
set(WINTUN_LICENSE "${trusttunnelclientwindows_SOURCE_DIR}/WINTUN_LICENSE.txt")

if(NOT EXISTS "${WINTUN_DLL}")
  message(FATAL_ERROR "wintun.dll not found at ${WINTUN_DLL}")
endif()

set(SERVICE_INSTALLER_EXE "${_TT_BIN_DIR}/service_installer.exe")
if(NOT EXISTS "${SERVICE_INSTALLER_EXE}")
  message(FATAL_ERROR "service_installer.exe not found at ${SERVICE_INSTALLER_EXE}")
endif()

message(STATUS "Using vpn_easy_service.exe: ${VPN_SERVICE_EXE}")
message(STATUS "Using wintun.dll: ${WINTUN_DLL}")
message(STATUS "Using service_installer.exe: ${SERVICE_INSTALLER_EXE}")

# Bundle the executables, DLLs and license so the app-level install step copies
# them next to the main executable at runtime.
set(vpn_plugin_bundled_libraries
  "${VPN_SERVICE_EXE}"
  "${VPN_EASY_DLL}"
  "${WINTUN_DLL}"
  "${WINTUN_LICENSE}"
  "${SERVICE_INSTALLER_EXE}"
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
include(FetchContent)
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
add_executable(${TEST_RUNNER}
  test/vpn_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_include_directories(${TEST_RUNNER} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin)
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
# flutter_wrapper_plugin has link dependencies on the Flutter DLL.
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)

# Enable automatic test discovery.
include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER})
endif()
