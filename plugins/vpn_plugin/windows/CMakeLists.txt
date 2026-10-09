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

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
target_link_libraries(${PLUGIN_NAME} PRIVATE Shell32 Ole32)

# === Download and use prebuilt TrustTunnelClientWindows ===
set(TRUSTTUNNEL_CLIENT_VERSION "1.3.0-alpha.1")

# Determine the archive architecture from the Visual Studio target platform.
# CMAKE_SYSTEM_PROCESSOR may identify the host instead of the target.
string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _tt_system_processor)
string(TOLOWER "${CMAKE_VS_PLATFORM_NAME}" _tt_vs_platform)
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Unsupported pointer size: ${CMAKE_SIZEOF_VOID_P}")
endif()
if(_tt_vs_platform)
  set(_tt_target_processor "${_tt_vs_platform}")
else()
  set(_tt_target_processor "${_tt_system_processor}")
endif()
if(_tt_target_processor MATCHES "^(amd64|x86_64|x64)$")
  set(TRUSTTUNNEL_CLIENT_ARCH "x86_64")
elseif(_tt_target_processor MATCHES "^(arm64|aarch64)$")
  set(TRUSTTUNNEL_CLIENT_ARCH "aarch64")
else()
  message(FATAL_ERROR "Unsupported Windows target architecture: ${_tt_target_processor}")
endif()

function(prepare_trusttunnel_client_windows
  version
  architecture
  archive_path
  output_dir
)
  set(_package_name "TrustTunnel Client ${version} for ${architecture}")
  set(_source_dir
    "${CMAKE_BINARY_DIR}/_deps/trusttunnel-client-windows")
  set(_complete_marker
    "${_source_dir}/${version}-${architecture}.complete")
  set(_package_config
    "${_source_dir}/lib/cmake/TrustTunnelClientWindows/TrustTunnelClientWindowsConfig.cmake")

  # Remove artifacts created by the former FetchContent-based download. They
  # can contain the credentialized package URL from an earlier configuration.
  file(REMOVE_RECURSE
    "${CMAKE_BINARY_DIR}/_deps/trusttunnelclientwindows-build"
    "${CMAKE_BINARY_DIR}/_deps/trusttunnelclientwindows-src"
    "${CMAKE_BINARY_DIR}/_deps/trusttunnelclientwindows-subbuild")

  if(
    EXISTS "${_complete_marker}" AND
    EXISTS "${_package_config}" AND
    EXISTS "${archive_path}"
  )
    set(${output_dir} "${_source_dir}" PARENT_SCOPE)
    return()
  endif()

  if("$ENV{GPR_KEY}" STREQUAL "")
    message(FATAL_ERROR
      "GPR_KEY is not set. Cannot download ${_package_name}.")
  endif()

  file(REMOVE_RECURSE "${_source_dir}")
  file(MAKE_DIRECTORY "${_source_dir}")
  get_filename_component(_download_dir "${archive_path}" DIRECTORY)
  file(MAKE_DIRECTORY "${_download_dir}")

  set(_archive_url
    "https://$ENV{GPR_KEY}:@maven.pkg.github.com/TrustTunnel/TrustTunnelClient/com/adguard/trusttunnel/trusttunnel-client-windows/${version}/trusttunnel-client-windows-${version}-${architecture}.zip")
  file(DOWNLOAD "${_archive_url}" "${archive_path}"
    STATUS _download_status
    TLS_VERIFY ON)
  unset(_archive_url)

  list(GET _download_status 0 _download_result)
  if(NOT _download_result EQUAL 0)
    file(REMOVE_RECURSE "${_source_dir}")
    file(REMOVE "${archive_path}")
    message(FATAL_ERROR "Failed to download ${_package_name}.")
  endif()

  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xvf "${archive_path}"
    WORKING_DIRECTORY "${_source_dir}"
    RESULT_VARIABLE _extract_result
    OUTPUT_QUIET
    ERROR_QUIET)

  if(NOT _extract_result EQUAL 0)
    file(REMOVE_RECURSE "${_source_dir}")
    message(FATAL_ERROR "Failed to extract ${_package_name}.")
  endif()

  if(NOT EXISTS "${_package_config}")
    file(REMOVE_RECURSE "${_source_dir}")
    message(FATAL_ERROR "${_package_name} is missing its CMake package file.")
  endif()

  file(WRITE "${_complete_marker}" "complete\n")
  set(${output_dir} "${_source_dir}" PARENT_SCOPE)
endfunction()

set(_trusttunnel_client_archive_path
  "${CMAKE_BINARY_DIR}/downloads/trusttunnel-client-windows-${TRUSTTUNNEL_CLIENT_VERSION}-${TRUSTTUNNEL_CLIENT_ARCH}.zip")
prepare_trusttunnel_client_windows(
  "${TRUSTTUNNEL_CLIENT_VERSION}"
  "${TRUSTTUNNEL_CLIENT_ARCH}"
  "${_trusttunnel_client_archive_path}"
  trusttunnelclientwindows_SOURCE_DIR)

file(SHA256
  "${_trusttunnel_client_archive_path}"
  _trusttunnel_client_archive_sha256)
set(TRUSTTUNNEL_CLIENT_RESOLVED_VERSION
  "${TRUSTTUNNEL_CLIENT_VERSION}"
  CACHE INTERNAL "Resolved TrustTunnel Client version")
set(TRUSTTUNNEL_CLIENT_RESOLVED_ARCH
  "${TRUSTTUNNEL_CLIENT_ARCH}"
  CACHE INTERNAL "Resolved TrustTunnel Client architecture")
set(TRUSTTUNNEL_CLIENT_ARCHIVE_PATH
  "${_trusttunnel_client_archive_path}"
  CACHE INTERNAL "Downloaded TrustTunnel Client archive")
set(TRUSTTUNNEL_CLIENT_ARCHIVE_SHA256
  "${_trusttunnel_client_archive_sha256}"
  CACHE INTERNAL "SHA-256 of the downloaded TrustTunnel Client archive")

# The archive ships lib/cmake/TrustTunnelClientWindows/TrustTunnelClientWindowsConfig.cmake
# Register that location so find_package() can discover it.
list(APPEND CMAKE_PREFIX_PATH "${trusttunnelclientwindows_SOURCE_DIR}")

find_package(TrustTunnelClientWindows REQUIRED)
target_link_libraries(${PLUGIN_NAME} PRIVATE TrustTunnelClientWindows::trusttunnel)

# --- Bundle required adapter's targets ---
set(_TT_BIN_DIR "${trusttunnelclientwindows_SOURCE_DIR}/bin")

set(TRUSTTUNNEL_SERVICE_EXE "${_TT_BIN_DIR}/trusttunnel_service.exe")
if(NOT EXISTS "${TRUSTTUNNEL_SERVICE_EXE}")
  message(FATAL_ERROR "trusttunnel_service.exe not found at ${TRUSTTUNNEL_SERVICE_EXE}")
endif()

set(TRUSTTUNNEL_DLL "${_TT_BIN_DIR}/trusttunnel.dll")
if(NOT EXISTS "${TRUSTTUNNEL_DLL}")
  message(FATAL_ERROR "trusttunnel.dll not found at ${TRUSTTUNNEL_DLL}")
endif()

set(WINTUN_DLL "${_TT_BIN_DIR}/wintun.dll")
set(WINTUN_LICENSE "${trusttunnelclientwindows_SOURCE_DIR}/WINTUN_LICENSE.txt")

if(NOT EXISTS "${WINTUN_DLL}")
  message(FATAL_ERROR "wintun.dll not found at ${WINTUN_DLL}")
endif()

set(TRUSTTUNNEL_SERVICE_INSTALLER_EXE "${_TT_BIN_DIR}/trusttunnel_service_installer.exe")
if(NOT EXISTS "${TRUSTTUNNEL_SERVICE_INSTALLER_EXE}")
  message(FATAL_ERROR "trusttunnel_service_installer.exe not found at ${TRUSTTUNNEL_SERVICE_INSTALLER_EXE}")
endif()

message(STATUS "Using trusttunnel_service.exe: ${TRUSTTUNNEL_SERVICE_EXE}")
message(STATUS "Using wintun.dll: ${WINTUN_DLL}")
message(STATUS "Using trusttunnel_service_installer.exe: ${TRUSTTUNNEL_SERVICE_INSTALLER_EXE}")

# Bundle the executables, DLLs and license so the app-level install step copies
# them next to the main executable at runtime.
set(vpn_plugin_bundled_libraries
  "${TRUSTTUNNEL_SERVICE_EXE}"
  "${TRUSTTUNNEL_DLL}"
  "${WINTUN_DLL}"
  "${WINTUN_LICENSE}"
  "${TRUSTTUNNEL_SERVICE_INSTALLER_EXE}"
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
