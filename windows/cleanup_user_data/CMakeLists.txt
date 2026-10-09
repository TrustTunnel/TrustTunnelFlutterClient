cmake_minimum_required(VERSION 3.14)
project(cleanup_user_data_helper LANGUAGES CXX)

add_executable(cleanup_user_data_helper "cleanup_user_data_helper.cpp")
apply_standard_settings(cleanup_user_data_helper)

target_compile_definitions(cleanup_user_data_helper PRIVATE
  "NOMINMAX"
  "_WIN32_WINNT=0x0A00")
target_link_libraries(cleanup_user_data_helper PRIVATE advapi32 wtsapi32)

install(TARGETS cleanup_user_data_helper
  RUNTIME DESTINATION "$<TARGET_FILE_DIR:TrustTunnel>"
  COMPONENT Runtime)
