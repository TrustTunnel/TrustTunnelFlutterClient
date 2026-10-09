// Native user-context helpers shared by the runner and uninstall helper.
// Resolve the Windows session user's SID/profile and open their registry,
// rather than using the elevated installer's account. GUI launches use the
// verified session shell's token; this code has no Flutter dependencies.

// clang-format off: Windows types must precede SDDL/WTS declarations.
#include "user_context.h"
#include <sddl.h>
#include <wtsapi32.h>
#include <userenv.h>
// clang-format on

#include <utility>
#include <vector>

namespace windows_user_context {
namespace {
constexpr wchar_t kProfileListKey[] =
    L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\";
class Handle final {
 public:
  explicit Handle(HANDLE value) : value_(value) {}
  ~Handle() {
    if (value_ != nullptr) {
      ::CloseHandle(value_);
    }
  }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
  HANDLE get() const { return value_; }

 private:
  HANDLE value_;
};

// A different UAC administrator may need their assigned debug privilege to
// open the session user's shell. Restore the privilege after the handoff.
class DebugPrivilege final {
 public:
  DebugPrivilege() = default;
  ~DebugPrivilege() {
    if (token_ != nullptr) {
      if (changed_) {
        ::AdjustTokenPrivileges(token_, FALSE, &previous_, 0, nullptr, nullptr);
      }
      ::CloseHandle(token_);
    }
  }
  DebugPrivilege(const DebugPrivilege&) = delete;
  DebugPrivilege& operator=(const DebugPrivilege&) = delete;

  DWORD Enable() {
    if (!::OpenProcessToken(::GetCurrentProcess(),
                            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token_)) {
      return ::GetLastError();
    }
    TOKEN_PRIVILEGES requested{};
    requested.PrivilegeCount = 1;
    if (!::LookupPrivilegeValueW(nullptr, SE_DEBUG_NAME,
                                 &requested.Privileges[0].Luid)) {
      return ::GetLastError();
    }
    requested.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    DWORD bytes = 0;
    ::SetLastError(ERROR_SUCCESS);
    if (!::AdjustTokenPrivileges(token_, FALSE, &requested, sizeof(previous_),
                                 &previous_, &bytes)) {
      return ::GetLastError();
    }
    const DWORD status = ::GetLastError();
    changed_ = previous_.PrivilegeCount != 0;
    return status == ERROR_NOT_ALL_ASSIGNED ? ERROR_PRIVILEGE_NOT_HELD : status;
  }

 private:
  HANDLE token_ = nullptr;
  TOKEN_PRIVILEGES previous_{};
  bool changed_ = false;
};
}  // namespace

DWORD ReadProfilePath(const std::wstring& sid, std::wstring& profile_path) {
  const std::wstring key = std::wstring(kProfileListKey) + sid;
  DWORD byte_count = 0;
  LSTATUS status = ::RegGetValueW(
      HKEY_LOCAL_MACHINE, key.c_str(), L"ProfileImagePath",
      RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ, nullptr, nullptr, &byte_count);
  if (status != ERROR_SUCCESS) {
    return static_cast<DWORD>(status);
  }
  if (byte_count < sizeof(wchar_t)) {
    return ERROR_INVALID_DATA;
  }

  std::wstring value(byte_count / sizeof(wchar_t), L'\0');
  status = ::RegGetValueW(HKEY_LOCAL_MACHINE, key.c_str(), L"ProfileImagePath",
                          RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ, nullptr,
                          value.data(), &byte_count);
  if (status != ERROR_SUCCESS) {
    return static_cast<DWORD>(status);
  }

  while (!value.empty() && value.back() == L'\0') {
    value.pop_back();
  }
  if (value.empty()) {
    return ERROR_INVALID_DATA;
  }

  profile_path = std::move(value);
  return ERROR_SUCCESS;
}

DWORD CanonicalizeSid(const std::wstring& input, std::wstring& canonical_sid) {
  PSID sid = nullptr;
  if (!::ConvertStringSidToSidW(input.c_str(), &sid)) {
    return ::GetLastError();
  }
  LPWSTR value = nullptr;
  const BOOL converted = ::ConvertSidToStringSidW(sid, &value);
  const DWORD status = converted ? ERROR_SUCCESS : ::GetLastError();
  if (converted) {
    canonical_sid = value;
  }
  if (value != nullptr) {
    ::LocalFree(value);
  }
  ::LocalFree(sid);
  return status;
}

DWORD GetSessionUserSid(std::wstring& sid_string) {
  DWORD session_id = 0;
  if (!::ProcessIdToSessionId(::GetCurrentProcessId(), &session_id)) {
    return ::GetLastError();
  }

  if (session_id == 0) {
    return ERROR_NO_SUCH_LOGON_SESSION;
  }

  LPWSTR user_buffer = nullptr;
  LPWSTR domain_buffer = nullptr;
  DWORD user_bytes = 0;
  DWORD domain_bytes = 0;
  if (!::WTSQuerySessionInformationW(WTS_CURRENT_SERVER_HANDLE, session_id,
                                     WTSUserName, &user_buffer, &user_bytes) ||
      user_buffer == nullptr || user_buffer[0] == L'\0') {
    const DWORD win32_error = user_buffer == nullptr || user_buffer[0] == L'\0'
                                  ? ERROR_NO_SUCH_LOGON_SESSION
                                  : ::GetLastError();
    if (user_buffer != nullptr) {
      ::WTSFreeMemory(user_buffer);
    }
    return win32_error;
  }

  if (!::WTSQuerySessionInformationW(WTS_CURRENT_SERVER_HANDLE, session_id,
                                     WTSDomainName, &domain_buffer,
                                     &domain_bytes)) {
    const DWORD status = ::GetLastError();
    ::WTSFreeMemory(user_buffer);
    if (domain_buffer != nullptr) {
      ::WTSFreeMemory(domain_buffer);
    }
    return status;
  }
  std::wstring account_name;
  if (domain_buffer != nullptr && domain_buffer[0] != L'\0') {
    account_name = std::wstring(domain_buffer) + L"\\" + user_buffer;
  } else {
    account_name = user_buffer;
  }
  ::WTSFreeMemory(user_buffer);
  if (domain_buffer != nullptr) {
    ::WTSFreeMemory(domain_buffer);
  }

  DWORD sid_bytes = 0;
  DWORD referenced_domain_chars = 0;
  SID_NAME_USE sid_type = SidTypeUnknown;
  ::SetLastError(ERROR_SUCCESS);
  ::LookupAccountNameW(nullptr, account_name.c_str(), nullptr, &sid_bytes,
                       nullptr, &referenced_domain_chars, &sid_type);
  if (::GetLastError() != ERROR_INSUFFICIENT_BUFFER || sid_bytes == 0) {
    const DWORD status = ::GetLastError();
    return status == ERROR_SUCCESS ? ERROR_NONE_MAPPED : status;
  }

  std::vector<unsigned char> sid(sid_bytes);
  std::wstring referenced_domain(referenced_domain_chars, L'\0');
  if (!::LookupAccountNameW(
          nullptr, account_name.c_str(), sid.data(), &sid_bytes,
          referenced_domain.empty() ? nullptr : referenced_domain.data(),
          &referenced_domain_chars, &sid_type)) {
    return ::GetLastError();
  }
  if (sid_type != SidTypeUser) {
    return ERROR_NO_SUCH_USER;
  }

  LPWSTR converted_sid = nullptr;
  if (!::ConvertSidToStringSidW(sid.data(), &converted_sid)) {
    return ::GetLastError();
  }
  sid_string = converted_sid;
  ::LocalFree(converted_sid);
  return ERROR_SUCCESS;
}

LSTATUS OpenUserRegistry(const std::wstring& sid, const std::wstring& profile,
                         REGSAM access, HKEY* key,
                         RegistryHiveType& hive_type) {
  const LSTATUS status =
      ::RegOpenKeyExW(HKEY_USERS, sid.c_str(), 0, access, key);
  if (status == ERROR_SUCCESS) {
    hive_type = RegistryHiveType::kUser;
    return status;
  }
  // Only fall back for an unloaded hive; never bypass a loaded hive's ACL.
  if (status != ERROR_FILE_NOT_FOUND) {
    return status;
  }
  const std::wstring path = profile + L"\\NTUSER.DAT";
  const DWORD attributes = ::GetFileAttributesW(path.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES) {
    return ::GetLastError();
  }
  if (attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) {
    return ERROR_INVALID_DATA;
  }
  const LSTATUS load_status =
      ::RegLoadAppKeyW(path.c_str(), key, access, REG_PROCESS_APPKEY, 0);
  if (load_status == ERROR_SUCCESS) {
    hive_type = RegistryHiveType::kApplication;
  }
  return load_status;
}

DWORD GetTokenUserSid(HANDLE token, std::wstring& sid) {
  DWORD bytes = 0;
  ::GetTokenInformation(token, TokenUser, nullptr, 0, &bytes);
  if (bytes == 0) {
    return ::GetLastError();
  }
  std::vector<BYTE> buffer(bytes);
  if (!::GetTokenInformation(token, TokenUser, buffer.data(), bytes, &bytes)) {
    return ::GetLastError();
  }
  LPWSTR value = nullptr;
  if (!::ConvertSidToStringSidW(
          reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &value)) {
    return ::GetLastError();
  }
  sid = value;
  ::LocalFree(value);
  return ERROR_SUCCESS;
}

DWORD IsSessionUserToken(HANDLE token, const std::wstring& sid,
                         DWORD session_id, bool& matches) {
  matches = false;
  std::wstring token_sid;
  DWORD status = GetTokenUserSid(token, token_sid);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  DWORD token_session = 0;
  DWORD bytes = 0;
  if (!::GetTokenInformation(token, TokenSessionId, &token_session,
                             sizeof(token_session), &bytes)) {
    return ::GetLastError();
  }
  if (session_id == 0 || token_session != session_id || token_sid != sid) {
    return ERROR_SUCCESS;
  }
  TOKEN_ELEVATION elevation{};
  if (!::GetTokenInformation(token, TokenElevation, &elevation,
                             sizeof(elevation), &bytes)) {
    return ::GetLastError();
  }
  if (elevation.TokenIsElevated == 0) {
    matches = true;
    return ERROR_SUCCESS;
  }
  // A full token is expected with UAC disabled. Only an explicit, valid
  // EnableLUA=0 permits it; missing or unreadable policy never grants access.
  DWORD enable_lua = 1;
  bytes = sizeof(enable_lua);
  const LSTATUS policy_status = ::RegGetValueW(
      HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System",
      L"EnableLUA", RRF_RT_REG_DWORD | RRF_SUBKEY_WOW6464KEY, nullptr,
      &enable_lua, &bytes);
  if (policy_status != ERROR_SUCCESS) {
    return static_cast<DWORD>(policy_status);
  }
  if (bytes != sizeof(enable_lua) || enable_lua > 1) {
    return ERROR_INVALID_DATA;
  }
  matches = enable_lua == 0;
  return ERROR_SUCCESS;
}

DWORD LaunchAsSessionUser(const std::wstring& executable) {
  std::wstring sid;
  DWORD status = GetSessionUserSid(sid);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  DWORD session = 0;
  if (!::ProcessIdToSessionId(::GetCurrentProcessId(), &session)) {
    return ::GetLastError();
  }
  const HWND shell = ::GetShellWindow();
  if (shell == nullptr) {
    return ERROR_NO_SUCH_LOGON_SESSION;
  }
  DWORD shell_pid = 0;
  ::GetWindowThreadProcessId(shell, &shell_pid);
  DWORD shell_session = 0;
  if (shell_pid == 0 || !::ProcessIdToSessionId(shell_pid, &shell_session)) {
    return ERROR_NO_SUCH_LOGON_SESSION;
  }
  if (shell_session != session) {
    return ERROR_NO_SUCH_LOGON_SESSION;
  }
  DebugPrivilege debug_privilege;
  HANDLE raw_process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_CREATE_PROCESS,
                    FALSE, shell_pid);
  if (raw_process == nullptr && ::GetLastError() == ERROR_ACCESS_DENIED) {
    status = debug_privilege.Enable();
    if (status != ERROR_SUCCESS) {
      return status;
    }
    raw_process = ::OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_CREATE_PROCESS, FALSE,
        shell_pid);
  }
  const Handle process(raw_process);
  if (process.get() == nullptr) {
    return ::GetLastError();
  }
  HANDLE raw_token = nullptr;
  if (!::OpenProcessToken(process.get(), TOKEN_QUERY | TOKEN_DUPLICATE,
                          &raw_token)) {
    return ::GetLastError();
  }
  const Handle token(raw_token);
  bool matches = false;
  status = IsSessionUserToken(token.get(), sid, session, matches);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  if (!matches) {
    return ERROR_ACCESS_DENIED;
  }
  STARTUPINFOEXW startup{};
  startup.StartupInfo.cb = sizeof(startup);
  startup.StartupInfo.dwFlags = STARTF_USESHOWWINDOW;
  startup.StartupInfo.wShowWindow = SW_SHOWNORMAL;
  SIZE_T attribute_bytes = 0;
  ::InitializeProcThreadAttributeList(nullptr, 1, 0, &attribute_bytes);
  if (attribute_bytes == 0) {
    return ::GetLastError();
  }
  std::vector<BYTE> attributes(attribute_bytes);
  startup.lpAttributeList =
      reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attributes.data());
  if (!::InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0,
                                           &attribute_bytes)) {
    return ::GetLastError();
  }
  HANDLE parent = process.get();
  if (!::UpdateProcThreadAttribute(startup.lpAttributeList, 0,
                                   PROC_THREAD_ATTRIBUTE_PARENT_PROCESS,
                                   &parent, sizeof(parent), nullptr, nullptr)) {
    status = ::GetLastError();
    ::DeleteProcThreadAttributeList(startup.lpAttributeList);
    return status;
  }
  void* environment = nullptr;
  if (!::CreateEnvironmentBlock(&environment, token.get(), FALSE)) {
    status = ::GetLastError();
    ::DeleteProcThreadAttributeList(startup.lpAttributeList);
    return status;
  }
  PROCESS_INFORMATION child{};
  std::wstring command = L"\"" + executable + L"\"";
  const std::wstring directory =
      executable.substr(0, executable.find_last_of(L"\\/"));
  // The documented parent-process attribute inherits the shell's process
  // token, device map and job rather than the elevated dispatcher's context.
  // Use the user's environment too, and verify the suspended child before any
  // Flutter code can run (including if a future manifest requests elevation).
  const BOOL started = ::CreateProcessW(
      executable.c_str(), command.data(), nullptr, nullptr, FALSE,
      EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT |
          CREATE_SUSPENDED,
      environment, directory.c_str(), &startup.StartupInfo, &child);
  status = started ? ERROR_SUCCESS : ::GetLastError();
  ::DestroyEnvironmentBlock(environment);
  ::DeleteProcThreadAttributeList(startup.lpAttributeList);
  if (started) {
    HANDLE child_token = nullptr;
    if (!::OpenProcessToken(child.hProcess, TOKEN_QUERY, &child_token)) {
      status = ::GetLastError();
    } else {
      status = IsSessionUserToken(child_token, sid, session, matches);
      ::CloseHandle(child_token);
      if (status == ERROR_SUCCESS && !matches) {
        status = ERROR_ACCESS_DENIED;
      }
    }
    DWORD child_session = 0;
    if (status == ERROR_SUCCESS &&
        (!::ProcessIdToSessionId(child.dwProcessId, &child_session) ||
         child_session != session)) {
      status = ERROR_NO_SUCH_LOGON_SESSION;
    }
    if (status == ERROR_SUCCESS) {
      ::AllowSetForegroundWindow(child.dwProcessId);
      if (::ResumeThread(child.hThread) == static_cast<DWORD>(-1)) {
        status = ::GetLastError();
      }
    }
    if (status != ERROR_SUCCESS) {
      ::TerminateProcess(child.hProcess, status);
    }
    ::CloseHandle(child.hThread);
    ::CloseHandle(child.hProcess);
  }
  return status;
}

}  // namespace windows_user_context
