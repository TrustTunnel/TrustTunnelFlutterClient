# Locates the Rust `trusttunnel_deeplink_ffi` library used for `tt://` deep
# links.
#
# Resolution order:
#   1. TrustTunnel Client release archive (zip):
#      a. TRUSTTUNNEL_CLIENT_ARCHIVE_PATH — CMake cache variable or environment
#         variable with the path to the archive;
#      b. <project root>/build/downloads/trusttunnel-client-linux-<version>-<arch>.zip
#         (the shared project-wide download cache; survives debug/release
#         switches);
#      c. <build dir>/downloads/trusttunnel-client-linux-<version>-<arch>.zip;
#      d. GitHub Packages Maven repository via GPR_KEY (downloaded to c.).
#      The archive is extracted and both the deeplink static library and the
#      `trusttunneld` daemon are taken from it (see TRUSTTUNNEL_CLIENT_DAEMON).
#   2. TRUSTTUNNEL_DEEPLINK_STATIC_LIB — path to a prebuilt
#      libtrusttunnel_deeplink_ffi.a.
#   3. TRUSTTUNNEL_CLIENT_SOURCE_DIR (CMake cache variable or environment
#      variable) — a TrustTunnelClient checkout containing
#      trusttunnel/deeplink-ffi. The static library is built with Cargo into
#      the plugin build directory.
#
# The resulting target `trusttunnel_deeplink_ffi` is an imported static
# library with the vendored FFI header on its include path. Link it together
# with Threads::Threads, ${CMAKE_DL_LIBS}, and m (the Rust standard library
# needs those on Linux).

include_guard(GLOBAL)

find_package(Threads REQUIRED)

set(TRUSTTUNNEL_CLIENT_VERSION "1.3.0-rc.2" CACHE STRING
  "TrustTunnel Client release version to download")
set(TRUSTTUNNEL_CLIENT_ARCHIVE_PATH "" CACHE FILEPATH
  "Path to the trusttunnel-client-linux-<version>-<arch>.zip release archive")
set(TRUSTTUNNEL_DEEPLINK_STATIC_LIB "" CACHE FILEPATH
  "Path to a prebuilt libtrusttunnel_deeplink_ffi.a")
set(TRUSTTUNNEL_CLIENT_SOURCE_DIR "" CACHE PATH
  "Path to a TrustTunnelClient checkout (contains trusttunnel/deeplink-ffi)")

# The plugin directory, resolved to the real path: the flutter tool adds
# plugins through .plugin_symlinks symlinks, so the plain
# CMAKE_CURRENT_LIST_DIR may point into flutter/ephemeral.
# (this file lives in linux/cmake/, so step one level up)
set(_tt_plugin_dir "${CMAKE_CURRENT_LIST_DIR}/..")
get_filename_component(_tt_plugin_dir "${_tt_plugin_dir}" REALPATH)

# ---------------------------------------------------------------------------
# TrustTunnel Client release archive
# ---------------------------------------------------------------------------
set(_tt_archive_name
  "trusttunnel-client-linux-${TRUSTTUNNEL_CLIENT_VERSION}-${CMAKE_SYSTEM_PROCESSOR}.zip")
set(_tt_project_downloads_dir "${_tt_plugin_dir}/../../../build/downloads")
get_filename_component(_tt_project_downloads_dir "${_tt_project_downloads_dir}" ABSOLUTE)

function(_tt_resolve_client_archive archive_name out_archive)
  set(_candidates "")
  if (TRUSTTUNNEL_CLIENT_ARCHIVE_PATH)
    list(APPEND _candidates "${TRUSTTUNNEL_CLIENT_ARCHIVE_PATH}")
  endif ()
  if (DEFINED ENV{TRUSTTUNNEL_CLIENT_ARCHIVE_PATH}
      AND NOT "$ENV{TRUSTTUNNEL_CLIENT_ARCHIVE_PATH}" STREQUAL "")
    list(APPEND _candidates "$ENV{TRUSTTUNNEL_CLIENT_ARCHIVE_PATH}")
  endif ()
  list(APPEND _candidates
    "${_tt_project_downloads_dir}/${archive_name}"
    "${CMAKE_BINARY_DIR}/downloads/${archive_name}")

  foreach (_candidate IN LISTS _candidates)
    # Normalize first: EXISTS is unreliable for ../..-paths under the
    # .plugin_symlinks symlink layout
    get_filename_component(_candidate "${_candidate}" ABSOLUTE)
    if (EXISTS "${_candidate}")
      set(${out_archive} "${_candidate}" PARENT_SCOPE)
      return()
    endif ()
  endforeach ()
  set(${out_archive} "" PARENT_SCOPE)
endfunction()

function(_tt_prepare_client_archive archive_path version architecture output_dir)
  set(_package_name "TrustTunnel Client ${version} for Linux ${architecture}")
  set(_source_dir "${CMAKE_BINARY_DIR}/_deps/trusttunnel-client-linux")
  set(_complete_marker "${_source_dir}/${version}-${architecture}.complete")
  set(_package_config
    "${_source_dir}/lib/cmake/TrustTunnelClientLinux/TrustTunnelClientLinuxConfig.cmake")

  if (
    EXISTS "${_complete_marker}" AND
    EXISTS "${_package_config}" AND
    EXISTS "${archive_path}"
  )
    set(${output_dir} "${_source_dir}" PARENT_SCOPE)
    return()
  endif ()

  file(REMOVE_RECURSE "${_source_dir}")
  file(MAKE_DIRECTORY "${_source_dir}")

  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xvf "${archive_path}"
    WORKING_DIRECTORY "${_source_dir}"
    RESULT_VARIABLE _extract_result
    OUTPUT_QUIET
    ERROR_QUIET)

  if (NOT _extract_result EQUAL 0)
    file(REMOVE_RECURSE "${_source_dir}")
    message(FATAL_ERROR "Failed to extract ${_package_name}.")
  endif ()

  if (NOT EXISTS "${_package_config}")
    file(REMOVE_RECURSE "${_source_dir}")
    message(FATAL_ERROR "${_package_name} is missing its CMake package file.")
  endif ()

  file(WRITE "${_complete_marker}" "complete\n")
  set(${output_dir} "${_source_dir}" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# Select the library source
# ---------------------------------------------------------------------------
set(_tt_library "")
set(_tt_build_target "")
set(_tt_archive_mode FALSE)

if (CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
  set(_tt_arch "x86_64")
elseif (CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(_tt_arch "aarch64")
else ()
  set(_tt_arch "")
endif ()

if (NOT _tt_arch)
  message(STATUS
    "trusttunnel_deeplink_ffi: unsupported architecture "
    "${CMAKE_SYSTEM_PROCESSOR}, skipping the release archive resolution")
else ()
  _tt_resolve_client_archive(
    "trusttunnel-client-linux-${TRUSTTUNNEL_CLIENT_VERSION}-${_tt_arch}.zip"
    _tt_archive_path)
endif ()

if (_tt_archive_path)
  _tt_prepare_client_archive(
    "${_tt_archive_path}"
    "${TRUSTTUNNEL_CLIENT_VERSION}"
    "${_tt_arch}"
    _tt_client_dir)
  set(_tt_library "${_tt_client_dir}/lib/libtrusttunnel_deeplink_ffi.a")
  set(TRUSTTUNNEL_CLIENT_DAEMON "${_tt_client_dir}/bin/trusttunneld" CACHE FILEPATH
    "trusttunneld daemon from the resolved TrustTunnel Client archive" FORCE)
  set(_tt_archive_mode TRUE)
elseif (TRUSTTUNNEL_DEEPLINK_STATIC_LIB)
  if (NOT EXISTS "${TRUSTTUNNEL_DEEPLINK_STATIC_LIB}")
    message(FATAL_ERROR
      "TRUSTTUNNEL_DEEPLINK_STATIC_LIB does not exist: ${TRUSTTUNNEL_DEEPLINK_STATIC_LIB}")
  endif ()
  set(_tt_library "${TRUSTTUNNEL_DEEPLINK_STATIC_LIB}")
else ()
  set(_tt_client_source "${TRUSTTUNNEL_CLIENT_SOURCE_DIR}")
  if (NOT _tt_client_source AND DEFINED ENV{TRUSTTUNNEL_CLIENT_SOURCE_DIR}
      AND NOT "$ENV{TRUSTTUNNEL_CLIENT_SOURCE_DIR}" STREQUAL "")
    # Persist the environment value so later automatic reconfigures keep working.
    set(TRUSTTUNNEL_CLIENT_SOURCE_DIR "$ENV{TRUSTTUNNEL_CLIENT_SOURCE_DIR}" CACHE PATH
      "Path to a TrustTunnelClient checkout (contains trusttunnel/deeplink-ffi)" FORCE)
    set(_tt_client_source "${TRUSTTUNNEL_CLIENT_SOURCE_DIR}")
  endif ()

  if (NOT _tt_client_source)
    message(FATAL_ERROR
      "trusttunnel_deeplink_ffi is not available. Put the release archive "
      "trusttunnel-client-linux-${TRUSTTUNNEL_CLIENT_VERSION}-<arch>.zip into "
      "${_tt_project_downloads_dir} (or set TRUSTTUNNEL_CLIENT_ARCHIVE_PATH, "
      "or GPR_KEY to download it), or set TRUSTTUNNEL_DEEPLINK_STATIC_LIB, "
      "or set TRUSTTUNNEL_CLIENT_SOURCE_DIR to a TrustTunnelClient checkout.")
  endif ()

  set(_tt_manifest "${_tt_client_source}/trusttunnel/Cargo.toml")
  if (NOT EXISTS "${_tt_manifest}")
    message(FATAL_ERROR
      "TRUSTTUNNEL_CLIENT_SOURCE_DIR does not point to a TrustTunnelClient checkout "
      "(missing ${_tt_manifest})")
  endif ()

  find_program(CARGO_EXECUTABLE cargo)
  if (NOT CARGO_EXECUTABLE)
    message(FATAL_ERROR
      "Cargo is required to build trusttunnel_deeplink_ffi. Install Rust or provide "
      "TRUSTTUNNEL_DEEPLINK_STATIC_LIB.")
  endif ()

  set(_tt_cargo_target_dir "${CMAKE_CURRENT_BINARY_DIR}/trusttunnel_deeplink_ffi")
  set(_tt_library
    "${_tt_cargo_target_dir}/release/${CMAKE_STATIC_LIBRARY_PREFIX}trusttunnel_deeplink_ffi${CMAKE_STATIC_LIBRARY_SUFFIX}")

  file(GLOB_RECURSE _tt_rust_sources
    "${_tt_client_source}/trusttunnel/deeplink-ffi/src/*.rs"
    "${_tt_client_source}/trusttunnel/settings/src/*.rs")

  add_custom_command(
    OUTPUT "${_tt_library}"
    COMMAND "${CMAKE_COMMAND}" -E env
      "CARGO_BUILD_TARGET_DIR=${_tt_cargo_target_dir}"
      "CARGO_PROFILE_RELEASE_DEBUG=false"
      "${CARGO_EXECUTABLE}" build --release --locked --package trusttunnel-deeplink-ffi
      --manifest-path "${_tt_manifest}"
    DEPENDS
      "${_tt_manifest}"
      "${_tt_client_source}/trusttunnel/Cargo.lock"
      "${_tt_client_source}/trusttunnel/deeplink-ffi/Cargo.toml"
      "${_tt_client_source}/trusttunnel/settings/Cargo.toml"
      ${_tt_rust_sources}
    WORKING_DIRECTORY "${_tt_client_source}/trusttunnel"
    COMMENT "Building Rust trusttunnel-deeplink-ffi"
    VERBATIM)

  add_custom_target(trusttunnel_deeplink_ffi_build DEPENDS "${_tt_library}")
  set(_tt_build_target trusttunnel_deeplink_ffi_build)
endif ()

if (_tt_archive_mode)
  message(STATUS
    "trusttunnel_deeplink_ffi: using release archive ${_tt_archive_path}")
endif ()

get_filename_component(_tt_header_dir "${_tt_plugin_dir}" ABSOLUTE)

add_library(trusttunnel_deeplink_ffi STATIC IMPORTED GLOBAL)
set_target_properties(trusttunnel_deeplink_ffi PROPERTIES
  IMPORTED_LOCATION "${_tt_library}"
  INTERFACE_INCLUDE_DIRECTORIES "${_tt_header_dir}")
if (_tt_build_target)
  add_dependencies(trusttunnel_deeplink_ffi ${_tt_build_target})
endif ()

set(TRUSTTUNNEL_DEEPLINK_LIBRARIES
  trusttunnel_deeplink_ffi
  Threads::Threads
  ${CMAKE_DL_LIBS}
  m
)
