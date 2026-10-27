#include "windows_installer.h"

// clang-format off: Shell APIs require Windows types first.
#include <windows.h>
#include <shellapi.h>
// clang-format on

#include <string>

#include "../user_context/launch_at_login_registry.h"
#include "../user_context/user_context.h"

namespace {

DWORD ConfigureLaunchAtLogin(const std::wstring& requested_sid) {
  using namespace windows_user_context;
  std::wstring sid;
  DWORD status = GetSessionUserSid(sid);
  if (!requested_sid.empty()) {
    std::wstring explicit_sid;
    const DWORD sid_status = CanonicalizeSid(requested_sid, explicit_sid);
    if (sid_status != ERROR_SUCCESS) {
      return sid_status;
    }
    DWORD session = 0;
    if (!::ProcessIdToSessionId(::GetCurrentProcessId(), &session)) {
      return ::GetLastError();
    }
    // Interactive installations can only target their session's user. Session
    // 0 automation must name a user explicitly and never launches their GUI.
    if (session != 0 && (status != ERROR_SUCCESS || sid != explicit_sid)) {
      return ERROR_NO_SUCH_LOGON_SESSION;
    }
    sid = explicit_sid;
  } else if (status != ERROR_SUCCESS) {
    return status;
  }
  std::wstring profile;
  status = ReadProfilePath(sid, profile);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  HKEY user = nullptr;
  RegistryHiveType hive_type;
  status =
      OpenUserRegistry(sid, profile, KEY_READ | KEY_WRITE, &user, hive_type);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  status = windows_launch_at_login::SetEnabled(user, true, hive_type);
  ::RegCloseKey(user);
  return status;
}

DWORD CheckLaunchContext() {
  std::wstring sid;
  DWORD status = windows_user_context::GetSessionUserSid(sid);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  DWORD session = 0;
  if (!::ProcessIdToSessionId(::GetCurrentProcessId(), &session)) {
    return ::GetLastError();
  }
  HANDLE token = nullptr;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return ::GetLastError();
  }
  bool matches = false;
  status =
      windows_user_context::IsSessionUserToken(token, sid, session, matches);
  ::CloseHandle(token);
  return status != ERROR_SUCCESS
             ? status
             : (matches ? ERROR_SUCCESS : ERROR_ELEVATION_REQUIRED);
}

DWORD LaunchInstalledApplication() {
  std::wstring executable(32768, L'\0');
  const DWORD length = ::GetModuleFileNameW(
      nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0) {
    return ::GetLastError();
  }
  if (length >= executable.size()) {
    return ERROR_FILENAME_EXCED_RANGE;
  }
  executable.resize(length);
  return windows_user_context::LaunchAsSessionUser(executable);
}

}  // namespace

std::optional<int> RunWindowsInstallerCommand() {
  int count = 0;
  LPWSTR* raw = ::CommandLineToArgvW(::GetCommandLineW(), &count);
  if (raw == nullptr) {
    return static_cast<int>(::GetLastError());
  }
  const std::wstring mode = count > 1 ? raw[1] : L"";
  const bool configure = mode == L"--configure-launch-at-login";
  const bool check = mode == L"--check-install-launch-context";
  const bool launch = mode == L"--launch-installed-application";
  if (!configure && !check && !launch) {
    ::LocalFree(raw);
    return std::nullopt;
  }
  std::wstring requested_sid;
  bool valid = count == 2;
  if (configure && count == 3) {
    const std::wstring argument = raw[2];
    const std::wstring prefix = L"--user-sid=";
    valid = argument.compare(0, prefix.size(), prefix) == 0 &&
            argument.size() > prefix.size();
    if (valid) {
      requested_sid = argument.substr(prefix.size());
    }
  }
  ::LocalFree(raw);
  if (!valid) {
    return ERROR_INVALID_PARAMETER;
  }
  return static_cast<int>(configure ? ConfigureLaunchAtLogin(requested_sid)
                                    : (check ? CheckLaunchContext()
                                             : LaunchInstalledApplication()));
}
