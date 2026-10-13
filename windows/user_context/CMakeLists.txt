add_library(windows_user_context STATIC
  "user_context.cpp"
  "launch_at_login_registry.cpp"
)
apply_standard_settings(windows_user_context)
target_compile_definitions(windows_user_context PRIVATE
  "NOMINMAX" "_WIN32_WINNT=0x0A00")
target_link_libraries(windows_user_context PUBLIC
  advapi32 ktmw32 shell32 userenv wtsapi32 user32)
