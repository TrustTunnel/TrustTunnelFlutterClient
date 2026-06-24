cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "tray_manager")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "tray_manager_plugin")

list(APPEND PLUGIN_SOURCES
  "tray_manager_plugin.cpp"
  "tray_manager_plugin.h"
  "tray_manager_plugin_dark_mode.cpp"
  "tray_manager_plugin_helpers.cpp"
  "tray_manager_plugin_helpers.h"
  "tray_manager_plugin_icon.cpp"
  "tray_manager_plugin_menu.cpp"
)

add_library(${PLUGIN_NAME} SHARED
  "include/tray_manager/tray_manager_plugin_c_api.h"
  "tray_manager_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin shlwapi windowscodecs)

set(tray_manager_bundled_libraries
  ""
  PARENT_SCOPE
)

