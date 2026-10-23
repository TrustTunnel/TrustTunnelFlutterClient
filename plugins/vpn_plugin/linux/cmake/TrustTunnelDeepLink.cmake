# Locates or builds the Rust `trusttunnel_deeplink_ffi` library used for
# `tt://` deep links.
#
# Resolution order:
#   1. TRUSTTUNNEL_DEEPLINK_STATIC_LIB — path to a prebuilt
#      libtrusttunnel_deeplink_ffi.a.
#   2. TRUSTTUNNEL_CLIENT_SOURCE_DIR (CMake cache variable or environment
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

set(TRUSTTUNNEL_CLIENT_SOURCE_DIR "" CACHE PATH
  "Path to a TrustTunnelClient checkout (contains trusttunnel/deeplink-ffi)")
set(TRUSTTUNNEL_DEEPLINK_STATIC_LIB "" CACHE FILEPATH
  "Path to a prebuilt libtrusttunnel_deeplink_ffi.a")

set(_tt_client_source "${TRUSTTUNNEL_CLIENT_SOURCE_DIR}")
if (NOT _tt_client_source AND DEFINED ENV{TRUSTTUNNEL_CLIENT_SOURCE_DIR}
    AND NOT "$ENV{TRUSTTUNNEL_CLIENT_SOURCE_DIR}" STREQUAL "")
  # Persist the environment value so later automatic reconfigures keep working.
  set(TRUSTTUNNEL_CLIENT_SOURCE_DIR "$ENV{TRUSTTUNNEL_CLIENT_SOURCE_DIR}" CACHE PATH
    "Path to a TrustTunnelClient checkout (contains trusttunnel/deeplink-ffi)" FORCE)
  set(_tt_client_source "${TRUSTTUNNEL_CLIENT_SOURCE_DIR}")
endif()

set(_tt_library "")
set(_tt_build_target "")

if (TRUSTTUNNEL_DEEPLINK_STATIC_LIB)
  if (NOT EXISTS "${TRUSTTUNNEL_DEEPLINK_STATIC_LIB}")
    message(FATAL_ERROR
      "TRUSTTUNNEL_DEEPLINK_STATIC_LIB does not exist: ${TRUSTTUNNEL_DEEPLINK_STATIC_LIB}")
  endif ()
  set(_tt_library "${TRUSTTUNNEL_DEEPLINK_STATIC_LIB}")
elseif (_tt_client_source)
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
else ()
  message(FATAL_ERROR
    "trusttunnel_deeplink_ffi is not available. Set TRUSTTUNNEL_CLIENT_SOURCE_DIR "
    "(CMake cache variable or environment variable) to a TrustTunnelClient checkout, "
    "or set TRUSTTUNNEL_DEEPLINK_STATIC_LIB to a prebuilt "
    "libtrusttunnel_deeplink_ffi.a.")
endif ()

get_filename_component(_tt_plugin_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

add_library(trusttunnel_deeplink_ffi STATIC IMPORTED GLOBAL)
set_target_properties(trusttunnel_deeplink_ffi PROPERTIES
  IMPORTED_LOCATION "${_tt_library}"
  INTERFACE_INCLUDE_DIRECTORIES "${_tt_plugin_dir}")
if (_tt_build_target)
  add_dependencies(trusttunnel_deeplink_ffi ${_tt_build_target})
endif ()

set(TRUSTTUNNEL_DEEPLINK_LIBRARIES
  trusttunnel_deeplink_ffi
  Threads::Threads
  ${CMAKE_DL_LIBS}
  m
)
