// Elevated Inno helper that removes selected TrustTunnel user data.
//
// - Dart application logs — cleanup_user_data_helper.exe.
// - Drift database and Shared Preferences — cleanup_user_data_helper.exe.
// - Temporary native-log exports — cleanup_user_data_helper.exe.
// - Native client and service VPN logs — Inno uninstaller.
// - VPN connection-log ring buffer — Inno uninstaller.

// clang-format off: Windows types must be declared before SDDL/WTS APIs.
#include <windows.h>
#include <sddl.h>
#include <wtsapi32.h>
// clang-format on

#include <string>
#include <utility>
#include <vector>

namespace {

enum class CleanupExitCode : int {
  // Success; Inno continues without a warning.
  kSuccess = 0,
  // Partial failure; Inno warns the user and continues uninstalling.
  kPartialFailure = 1,
  // User/profile lookup failed; Inno warns and continues uninstalling.
  kUserResolutionFailure = 2,
  // A target escaped its allowed root; Inno warns and continues uninstalling.
  kPathOutsideAllowedRoot = 3,
  // Helper setup/path resolution failed; Inno warns and continues uninstalling.
  kInternalError = 4,
};

enum class CleanupStage {
  kParseOptions,
  kCanonicalizeSid,
  kResolveInteractiveUser,
  kReadProfilePath,
  kOpenUserRegistry,
  kReadRoamingAppData,
  kReadTemporaryDirectory,
  kExpandUserEnvironment,
  kMakeAbsolutePath,
  kValidatePath,
  kEnumerateDirectory,
  kOpenPath,
  kReadAttributes,
  kDeletePath,
};

struct CleanupError {
  CleanupStage stage;
  std::wstring path;
  DWORD win32_error;
};

constexpr wchar_t kProfileListKey[] =
    L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\ProfileList\\";
constexpr wchar_t kUserShellFoldersKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\User Shell "
    L"Folders";
constexpr wchar_t kUserEnvironmentKey[] = L"Environment";
constexpr wchar_t kVolatileEnvironmentKey[] = L"Volatile Environment";
constexpr wchar_t kTemporaryExportPrefix[] = L"trusttunnel_windows_logs_";
constexpr size_t kTemporaryExportPrefixLength =
    sizeof(kTemporaryExportPrefix) / sizeof(wchar_t) - 1;

const wchar_t* CleanupStageName(CleanupStage stage) {
  switch (stage) {
    case CleanupStage::kParseOptions:
      return L"parse_options";
    case CleanupStage::kCanonicalizeSid:
      return L"canonicalize_sid";
    case CleanupStage::kResolveInteractiveUser:
      return L"resolve_interactive_user";
    case CleanupStage::kReadProfilePath:
      return L"read_profile_path";
    case CleanupStage::kOpenUserRegistry:
      return L"open_user_registry";
    case CleanupStage::kReadRoamingAppData:
      return L"read_roaming_app_data";
    case CleanupStage::kReadTemporaryDirectory:
      return L"read_temporary_directory";
    case CleanupStage::kExpandUserEnvironment:
      return L"expand_user_environment";
    case CleanupStage::kMakeAbsolutePath:
      return L"make_absolute_path";
    case CleanupStage::kValidatePath:
      return L"validate_path";
    case CleanupStage::kEnumerateDirectory:
      return L"enumerate_directory";
    case CleanupStage::kOpenPath:
      return L"open_path";
    case CleanupStage::kReadAttributes:
      return L"read_attributes";
    case CleanupStage::kDeletePath:
      return L"delete_path";
  }
  return L"unknown";
}

CleanupExitCode ExitCodeForError(const CleanupError& error) {
  switch (error.stage) {
    case CleanupStage::kCanonicalizeSid:
    case CleanupStage::kResolveInteractiveUser:
    case CleanupStage::kReadProfilePath:
    case CleanupStage::kOpenUserRegistry:
      return CleanupExitCode::kUserResolutionFailure;
    case CleanupStage::kValidatePath:
      return CleanupExitCode::kPathOutsideAllowedRoot;
    case CleanupStage::kEnumerateDirectory:
    case CleanupStage::kOpenPath:
    case CleanupStage::kReadAttributes:
    case CleanupStage::kDeletePath:
      return CleanupExitCode::kPartialFailure;
    case CleanupStage::kParseOptions:
    case CleanupStage::kReadRoamingAppData:
    case CleanupStage::kReadTemporaryDirectory:
    case CleanupStage::kExpandUserEnvironment:
    case CleanupStage::kMakeAbsolutePath:
      return CleanupExitCode::kInternalError;
  }
  return CleanupExitCode::kInternalError;
}

CleanupExitCode ExitCodeForErrors(const std::vector<CleanupError>& errors) {
  CleanupExitCode result = CleanupExitCode::kSuccess;
  for (const CleanupError& error : errors) {
    const CleanupExitCode error_code = ExitCodeForError(error);
    if (error_code == CleanupExitCode::kPathOutsideAllowedRoot ||
        error_code == CleanupExitCode::kUserResolutionFailure ||
        error_code == CleanupExitCode::kInternalError) {
      return error_code;
    }
    if (error_code == CleanupExitCode::kPartialFailure) {
      result = error_code;
    }
  }
  return result;
}

int ToProcessExitCode(CleanupExitCode exit_code) {
  return static_cast<int>(exit_code);
}

class Logger {
 public:
  Logger() : handle_(::GetStdHandle(STD_OUTPUT_HANDLE)) {}
  Logger(const Logger&) = delete;
  Logger& operator=(const Logger&) = delete;

  void Write(const std::wstring& message) const {
    if (handle_ == nullptr || handle_ == INVALID_HANDLE_VALUE) {
      return;
    }

    const std::wstring line = message + L"\r\n";
    const int byte_count = ::WideCharToMultiByte(CP_UTF8, 0, line.c_str(),
                                                 static_cast<int>(line.size()),
                                                 nullptr, 0, nullptr, nullptr);
    if (byte_count <= 0) {
      return;
    }

    std::string utf8(static_cast<size_t>(byte_count), '\0');
    if (::WideCharToMultiByte(CP_UTF8, 0, line.c_str(),
                              static_cast<int>(line.size()), utf8.data(),
                              byte_count, nullptr, nullptr) <= 0) {
      return;
    }

    DWORD bytes_written = 0;
    ::WriteFile(handle_, utf8.data(), static_cast<DWORD>(utf8.size()),
                &bytes_written, nullptr);
  }

  void WriteError(const CleanupError& error) const {
    Write(L"ERROR stage=" + std::wstring(CleanupStageName(error.stage)) +
          L" path=\"" + error.path + L"\" win32_error=" +
          std::to_wstring(error.win32_error));
  }

 private:
  HANDLE handle_;
};

class ScopedHandle {
 public:
  explicit ScopedHandle(HANDLE handle) : handle_(handle) {}
  ScopedHandle(const ScopedHandle&) = delete;
  ScopedHandle& operator=(const ScopedHandle&) = delete;

  ~ScopedHandle() {
    if (handle_ != nullptr && handle_ != INVALID_HANDLE_VALUE) {
      ::CloseHandle(handle_);
    }
  }

  HANDLE get() const { return handle_; }

 private:
  HANDLE handle_;
};

class ScopedFindHandle {
 public:
  explicit ScopedFindHandle(HANDLE handle) : handle_(handle) {}
  ScopedFindHandle(const ScopedFindHandle&) = delete;
  ScopedFindHandle& operator=(const ScopedFindHandle&) = delete;

  ~ScopedFindHandle() {
    if (handle_ != INVALID_HANDLE_VALUE) {
      ::FindClose(handle_);
    }
  }

 private:
  HANDLE handle_;
};

class ScopedRegistryKey {
 public:
  ScopedRegistryKey() = default;
  ScopedRegistryKey(const ScopedRegistryKey&) = delete;
  ScopedRegistryKey& operator=(const ScopedRegistryKey&) = delete;

  ~ScopedRegistryKey() {
    if (key_ != nullptr) {
      ::RegCloseKey(key_);
    }
  }

  HKEY get() const { return key_; }
  HKEY* receive() { return &key_; }

 private:
  HKEY key_ = nullptr;
};

bool EqualsIgnoreCase(const std::wstring& left, const std::wstring& right) {
  return ::CompareStringOrdinal(left.c_str(), static_cast<int>(left.size()),
                                right.c_str(), static_cast<int>(right.size()),
                                TRUE) == CSTR_EQUAL;
}

bool StartsWithIgnoreCase(const std::wstring& value,
                          const std::wstring& prefix) {
  return value.size() >= prefix.size() &&
         ::CompareStringOrdinal(value.c_str(), static_cast<int>(prefix.size()),
                                prefix.c_str(), static_cast<int>(prefix.size()),
                                TRUE) == CSTR_EQUAL;
}

std::wstring JoinPath(const std::wstring& base, const std::wstring& child) {
  if (base.empty() || base.back() == L'\\') {
    return base + child;
  }
  return base + L"\\" + child;
}

bool MakeAbsoluteLexicalPath(const std::wstring& path,
                             std::wstring* absolute_path, CleanupError* error) {
  const DWORD required = ::GetFullPathNameW(path.c_str(), 0, nullptr, nullptr);
  if (required == 0) {
    *error = {CleanupStage::kMakeAbsolutePath, path, ::GetLastError()};
    return false;
  }

  std::wstring buffer(static_cast<size_t>(required), L'\0');
  const DWORD length =
      ::GetFullPathNameW(path.c_str(), required, buffer.data(), nullptr);
  if (length == 0 || length >= required) {
    const DWORD win32_error =
        length == 0 ? ::GetLastError() : ERROR_INSUFFICIENT_BUFFER;
    *error = {CleanupStage::kMakeAbsolutePath, path, win32_error};
    return false;
  }

  buffer.resize(length);
  while (buffer.size() > 3 && buffer.back() == L'\\') {
    buffer.pop_back();
  }
  *absolute_path = std::move(buffer);
  return true;
}

bool IsStrictChildPath(const std::wstring& parent, const std::wstring& child) {
  if (parent.empty() || child.size() <= parent.size() ||
      !StartsWithIgnoreCase(child, parent)) {
    return false;
  }
  return parent.back() == L'\\' || child[parent.size()] == L'\\';
}

bool ReadProfilePath(const std::wstring& sid, std::wstring* profile_path,
                     CleanupError* error) {
  const std::wstring key = std::wstring(kProfileListKey) + sid;
  DWORD byte_count = 0;
  LSTATUS status = ::RegGetValueW(
      HKEY_LOCAL_MACHINE, key.c_str(), L"ProfileImagePath",
      RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ, nullptr, nullptr, &byte_count);
  if (status != ERROR_SUCCESS) {
    *error = {CleanupStage::kReadProfilePath, key, static_cast<DWORD>(status)};
    return false;
  }
  if (byte_count < sizeof(wchar_t)) {
    *error = {CleanupStage::kReadProfilePath, key, ERROR_INVALID_DATA};
    return false;
  }

  std::wstring value(byte_count / sizeof(wchar_t), L'\0');
  status = ::RegGetValueW(HKEY_LOCAL_MACHINE, key.c_str(), L"ProfileImagePath",
                          RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ, nullptr,
                          value.data(), &byte_count);
  if (status != ERROR_SUCCESS) {
    *error = {CleanupStage::kReadProfilePath, key, static_cast<DWORD>(status)};
    return false;
  }

  while (!value.empty() && value.back() == L'\0') {
    value.pop_back();
  }
  if (value.empty()) {
    *error = {CleanupStage::kReadProfilePath, key, ERROR_INVALID_DATA};
    return false;
  }

  *profile_path = std::move(value);
  return true;
}

bool CanonicalizeSid(const std::wstring& input, std::wstring* canonical_sid,
                     CleanupError* error) {
  PSID sid = nullptr;
  if (!::ConvertStringSidToSidW(input.c_str(), &sid)) {
    *error = {CleanupStage::kCanonicalizeSid, input, ::GetLastError()};
    return false;
  }

  bool result = false;
  if (::IsValidSid(sid)) {
    LPWSTR sid_string = nullptr;
    if (::ConvertSidToStringSidW(sid, &sid_string)) {
      *canonical_sid = sid_string;
      ::LocalFree(sid_string);
      result = true;
    } else {
      *error = {CleanupStage::kCanonicalizeSid, input, ::GetLastError()};
    }
  } else {
    *error = {CleanupStage::kCanonicalizeSid, input, ERROR_INVALID_SID};
  }

  ::LocalFree(sid);
  return result;
}

bool GetInteractiveSessionSid(std::wstring* sid_string, CleanupError* error) {
  DWORD session_id = 0;
  if (!::ProcessIdToSessionId(::GetCurrentProcessId(), &session_id)) {
    *error = {CleanupStage::kResolveInteractiveUser, L"session",
              ::GetLastError()};
    return false;
  }

  LPWSTR user_buffer = nullptr;
  LPWSTR domain_buffer = nullptr;
  DWORD user_bytes = 0;
  DWORD domain_bytes = 0;
  if (!::WTSQuerySessionInformationW(WTS_CURRENT_SERVER_HANDLE, session_id,
                                     WTSUserName, &user_buffer, &user_bytes) ||
      user_buffer == nullptr || user_buffer[0] == L'\0') {
    const DWORD win32_error = ::GetLastError();
    if (user_buffer != nullptr) {
      ::WTSFreeMemory(user_buffer);
    }
    *error = {CleanupStage::kResolveInteractiveUser, L"WTSUserName",
              win32_error};
    return false;
  }

  ::WTSQuerySessionInformationW(WTS_CURRENT_SERVER_HANDLE, session_id,
                                WTSDomainName, &domain_buffer, &domain_bytes);
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
    *error = {CleanupStage::kResolveInteractiveUser, account_name,
              ::GetLastError()};
    return false;
  }

  std::vector<unsigned char> sid(sid_bytes);
  std::wstring referenced_domain(referenced_domain_chars, L'\0');
  if (!::LookupAccountNameW(
          nullptr, account_name.c_str(), sid.data(), &sid_bytes,
          referenced_domain.empty() ? nullptr : referenced_domain.data(),
          &referenced_domain_chars, &sid_type)) {
    *error = {CleanupStage::kResolveInteractiveUser, account_name,
              ::GetLastError()};
    return false;
  }

  LPWSTR converted_sid = nullptr;
  if (!::ConvertSidToStringSidW(sid.data(), &converted_sid)) {
    *error = {CleanupStage::kResolveInteractiveUser, account_name,
              ::GetLastError()};
    return false;
  }
  *sid_string = converted_sid;
  ::LocalFree(converted_sid);
  return true;
}

bool OpenUserRegistry(const std::wstring& sid, const std::wstring& profile_path,
                      ScopedRegistryKey* user_registry, CleanupError* error) {
  LSTATUS status = ::RegOpenKeyExW(HKEY_USERS, sid.c_str(), 0, KEY_READ,
                                   user_registry->receive());
  if (status == ERROR_SUCCESS) {
    return true;
  }

  const std::wstring hive_path = JoinPath(profile_path, L"NTUSER.DAT");
  const DWORD hive_attributes = ::GetFileAttributesW(hive_path.c_str());
  if (hive_attributes == INVALID_FILE_ATTRIBUTES ||
      (hive_attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
    const DWORD win32_error = hive_attributes == INVALID_FILE_ATTRIBUTES
                                  ? ::GetLastError()
                                  : ERROR_INVALID_DATA;
    *error = {CleanupStage::kOpenUserRegistry, hive_path, win32_error};
    return false;
  }
  status = ::RegLoadAppKeyW(hive_path.c_str(), user_registry->receive(),
                            KEY_READ, REG_PROCESS_APPKEY, 0);
  if (status != ERROR_SUCCESS) {
    *error = {CleanupStage::kOpenUserRegistry, hive_path,
              static_cast<DWORD>(status)};
    return false;
  }
  return true;
}

enum class RegistryStringResult { kFound, kNotFound, kError };

RegistryStringResult ReadRegistryString(HKEY root, const wchar_t* subkey,
                                        const std::wstring& value_name,
                                        std::wstring* value,
                                        DWORD* win32_error) {
  DWORD byte_count = 0;
  LSTATUS status =
      ::RegGetValueW(root, subkey, value_name.c_str(),
                     RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ | RRF_NOEXPAND,
                     nullptr, nullptr, &byte_count);
  if (status == ERROR_FILE_NOT_FOUND) {
    return RegistryStringResult::kNotFound;
  }
  if (status != ERROR_SUCCESS) {
    *win32_error = static_cast<DWORD>(status);
    return RegistryStringResult::kError;
  }
  if (byte_count < sizeof(wchar_t)) {
    *win32_error = ERROR_INVALID_DATA;
    return RegistryStringResult::kError;
  }

  std::wstring buffer(byte_count / sizeof(wchar_t), L'\0');
  status = ::RegGetValueW(root, subkey, value_name.c_str(),
                          RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ | RRF_NOEXPAND,
                          nullptr, buffer.data(), &byte_count);
  if (status != ERROR_SUCCESS) {
    *win32_error = static_cast<DWORD>(status);
    return RegistryStringResult::kError;
  }
  while (!buffer.empty() && buffer.back() == L'\0') {
    buffer.pop_back();
  }
  if (buffer.empty()) {
    *win32_error = ERROR_INVALID_DATA;
    return RegistryStringResult::kError;
  }

  *value = std::move(buffer);
  return RegistryStringResult::kFound;
}

std::wstring ProfileHomeDrive(const std::wstring& profile_path) {
  if (profile_path.size() >= 2 && profile_path[1] == L':') {
    return profile_path.substr(0, 2);
  }
  return {};
}

std::wstring ProfileHomePath(const std::wstring& profile_path) {
  if (profile_path.size() >= 3 && profile_path[1] == L':') {
    return profile_path.substr(2);
  }
  return profile_path;
}

RegistryStringResult ReadUserEnvironmentValue(HKEY user_registry,
                                              const std::wstring& name,
                                              std::wstring* value,
                                              DWORD* win32_error) {
  RegistryStringResult result = ReadRegistryString(
      user_registry, kVolatileEnvironmentKey, name, value, win32_error);
  if (result != RegistryStringResult::kNotFound) {
    return result;
  }
  return ReadRegistryString(user_registry, kUserEnvironmentKey, name, value,
                            win32_error);
}

RegistryStringResult ReadProcessEnvironmentValue(const std::wstring& name,
                                                 std::wstring* value,
                                                 DWORD* win32_error) {
  ::SetLastError(ERROR_SUCCESS);
  const DWORD required = ::GetEnvironmentVariableW(name.c_str(), nullptr, 0);
  if (required == 0) {
    const DWORD status = ::GetLastError();
    if (status == ERROR_ENVVAR_NOT_FOUND || status == ERROR_SUCCESS) {
      return RegistryStringResult::kNotFound;
    }
    *win32_error = status;
    return RegistryStringResult::kError;
  }

  std::wstring buffer(required, L'\0');
  const DWORD length =
      ::GetEnvironmentVariableW(name.c_str(), buffer.data(), required);
  if (length == 0 || length >= required) {
    *win32_error = length == 0 ? ::GetLastError() : ERROR_INSUFFICIENT_BUFFER;
    return RegistryStringResult::kError;
  }
  buffer.resize(length);
  *value = std::move(buffer);
  return RegistryStringResult::kFound;
}

bool IsTargetUserEnvironmentName(const std::wstring& name) {
  return EqualsIgnoreCase(name, L"APPDATA") ||
         EqualsIgnoreCase(name, L"LOCALAPPDATA") ||
         EqualsIgnoreCase(name, L"TEMP") || EqualsIgnoreCase(name, L"TMP") ||
         EqualsIgnoreCase(name, L"USERPROFILE") ||
         EqualsIgnoreCase(name, L"HOMEDRIVE") ||
         EqualsIgnoreCase(name, L"HOMEPATH") ||
         EqualsIgnoreCase(name, L"USERNAME") ||
         EqualsIgnoreCase(name, L"USERDOMAIN") ||
         StartsWithIgnoreCase(name, L"ONEDRIVE");
}

bool ResolveUserEnvironmentValue(const std::wstring& name,
                                 const std::wstring& profile_path,
                                 HKEY user_registry, std::wstring* value,
                                 DWORD* win32_error) {
  if (EqualsIgnoreCase(name, L"USERPROFILE")) {
    *value = profile_path;
    return true;
  }
  if (EqualsIgnoreCase(name, L"HOMEDRIVE")) {
    *value = ProfileHomeDrive(profile_path);
    return !value->empty();
  }
  if (EqualsIgnoreCase(name, L"HOMEPATH")) {
    *value = ProfileHomePath(profile_path);
    return !value->empty();
  }

  RegistryStringResult result =
      ReadUserEnvironmentValue(user_registry, name, value, win32_error);
  if (result == RegistryStringResult::kFound) {
    return true;
  }
  if (result == RegistryStringResult::kError) {
    return false;
  }
  if (IsTargetUserEnvironmentName(name)) {
    *win32_error = ERROR_ENVVAR_NOT_FOUND;
    return false;
  }

  result = ReadProcessEnvironmentValue(name, value, win32_error);
  if (result == RegistryStringResult::kFound) {
    return true;
  }
  if (result == RegistryStringResult::kNotFound) {
    *win32_error = ERROR_ENVVAR_NOT_FOUND;
  }
  return false;
}

bool ExpandTargetUserEnvironment(const std::wstring& input,
                                 const std::wstring& profile_path,
                                 HKEY user_registry, std::wstring* expanded,
                                 CleanupError* error) {
  std::wstring result = input;
  for (int pass = 0; pass < 16; ++pass) {
    const size_t variable_start = result.find(L'%');
    if (variable_start == std::wstring::npos) {
      *expanded = std::move(result);
      return true;
    }
    const size_t variable_end = result.find(L'%', variable_start + 1);
    if (variable_end == std::wstring::npos ||
        variable_end == variable_start + 1) {
      *error = {CleanupStage::kExpandUserEnvironment, input,
                ERROR_INVALID_DATA};
      return false;
    }

    const std::wstring variable_name =
        result.substr(variable_start + 1, variable_end - variable_start - 1);
    std::wstring variable_value;
    DWORD win32_error = ERROR_SUCCESS;
    if (!ResolveUserEnvironmentValue(variable_name, profile_path, user_registry,
                                     &variable_value, &win32_error)) {
      *error = {CleanupStage::kExpandUserEnvironment, variable_name,
                win32_error};
      return false;
    }

    result.replace(variable_start, variable_end - variable_start + 1,
                   variable_value);
  }

  *error = {CleanupStage::kExpandUserEnvironment, input, ERROR_INVALID_DATA};
  return false;
}

bool ResolveRoamingAppData(HKEY user_registry, const std::wstring& profile_path,
                           std::wstring* roaming_app_data,
                           CleanupError* error) {
  std::wstring raw_path;
  DWORD win32_error = ERROR_SUCCESS;
  const RegistryStringResult result = ReadRegistryString(
      user_registry, kUserShellFoldersKey, L"AppData", &raw_path, &win32_error);
  if (result == RegistryStringResult::kError) {
    *error = {CleanupStage::kReadRoamingAppData,
              std::wstring(kUserShellFoldersKey) + L"\\AppData", win32_error};
    return false;
  }
  if (result == RegistryStringResult::kNotFound) {
    raw_path = JoinPath(profile_path, L"AppData\\Roaming");
  }

  std::wstring expanded_path;
  if (!ExpandTargetUserEnvironment(raw_path, profile_path, user_registry,
                                   &expanded_path, error)) {
    return false;
  }
  return MakeAbsoluteLexicalPath(expanded_path, roaming_app_data, error);
}

bool ResolveTemporaryDirectory(HKEY user_registry,
                               const std::wstring& profile_path,
                               std::wstring* temporary_directory,
                               CleanupError* error) {
  std::wstring raw_path;
  DWORD win32_error = ERROR_SUCCESS;
  std::wstring value_name = L"TMP";
  RegistryStringResult result = ReadUserEnvironmentValue(
      user_registry, value_name, &raw_path, &win32_error);
  if (result == RegistryStringResult::kNotFound) {
    value_name = L"TEMP";
    result = ReadUserEnvironmentValue(user_registry, value_name, &raw_path,
                                      &win32_error);
  }
  if (result == RegistryStringResult::kError) {
    *error = {CleanupStage::kReadTemporaryDirectory, value_name, win32_error};
    return false;
  }
  if (result == RegistryStringResult::kNotFound) {
    raw_path = profile_path;
  }

  std::wstring expanded_path;
  if (!ExpandTargetUserEnvironment(raw_path, profile_path, user_registry,
                                   &expanded_path, error)) {
    return false;
  }
  return MakeAbsoluteLexicalPath(expanded_path, temporary_directory, error);
}

bool RemoveKnownPath(const std::wstring& path, const Logger& logger,
                     std::vector<CleanupError>* errors) {
  const HANDLE raw_handle = ::CreateFileW(
      path.c_str(), DELETE | FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  if (raw_handle == INVALID_HANDLE_VALUE) {
    const DWORD win32_error = ::GetLastError();
    if (win32_error == ERROR_FILE_NOT_FOUND ||
        win32_error == ERROR_PATH_NOT_FOUND) {
      logger.Write(L"Not found: " + path);
      return true;
    }
    const CleanupError error{CleanupStage::kOpenPath, path, win32_error};
    errors->push_back(error);
    logger.WriteError(error);
    return false;
  }
  const ScopedHandle handle(raw_handle);

  FILE_ATTRIBUTE_TAG_INFO tag_info = {};
  if (!::GetFileInformationByHandleEx(handle.get(), FileAttributeTagInfo,
                                      &tag_info, sizeof(tag_info))) {
    const CleanupError error{CleanupStage::kReadAttributes, path,
                             ::GetLastError()};
    errors->push_back(error);
    logger.WriteError(error);
    return false;
  }
  const DWORD attributes = tag_info.FileAttributes;

  if ((attributes & FILE_ATTRIBUTE_DIRECTORY) != 0 &&
      (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0) {
    WIN32_FIND_DATAW find_data = {};
    const std::wstring search_pattern = JoinPath(path, L"*");
    HANDLE raw_find_handle =
        ::FindFirstFileW(search_pattern.c_str(), &find_data);
    if (raw_find_handle == INVALID_HANDLE_VALUE) {
      const DWORD win32_error = ::GetLastError();
      if (win32_error != ERROR_FILE_NOT_FOUND) {
        const CleanupError error{CleanupStage::kEnumerateDirectory, path,
                                 win32_error};
        errors->push_back(error);
        logger.WriteError(error);
        return false;
      }
    } else {
      const ScopedFindHandle find_handle(raw_find_handle);
      bool children_removed = true;
      do {
        if (!EqualsIgnoreCase(find_data.cFileName, L".") &&
            !EqualsIgnoreCase(find_data.cFileName, L"..")) {
          children_removed =
              RemoveKnownPath(JoinPath(path, find_data.cFileName), logger,
                              errors) &&
              children_removed;
        }
      } while (::FindNextFileW(raw_find_handle, &find_data));

      const DWORD find_error = ::GetLastError();
      if (find_error != ERROR_NO_MORE_FILES) {
        const CleanupError error{CleanupStage::kEnumerateDirectory, path,
                                 find_error};
        errors->push_back(error);
        logger.WriteError(error);
        children_removed = false;
      }
      if (!children_removed) {
        return false;
      }
    }
  }

  DWORD writable_attributes =
      attributes & ~(FILE_ATTRIBUTE_READONLY | FILE_ATTRIBUTE_SYSTEM);
  if (writable_attributes == 0) {
    writable_attributes = FILE_ATTRIBUTE_NORMAL;
  }
  if (writable_attributes != attributes) {
    ::SetFileAttributesW(path.c_str(), writable_attributes);
  }

  FILE_DISPOSITION_INFO disposition = {};
  disposition.DeleteFile = TRUE;
  if (!::SetFileInformationByHandle(handle.get(), FileDispositionInfo,
                                    &disposition, sizeof(disposition))) {
    const CleanupError error{CleanupStage::kDeletePath, path, ::GetLastError()};
    errors->push_back(error);
    logger.WriteError(error);
    return false;
  }

  logger.Write(L"Deleted: " + path);
  return true;
}

bool IsTemporaryExportName(const std::wstring& name) {
  if (!StartsWithIgnoreCase(name, kTemporaryExportPrefix) ||
      name.size() == kTemporaryExportPrefixLength) {
    return false;
  }
  for (size_t index = kTemporaryExportPrefixLength; index < name.size();
       ++index) {
    if (name[index] < L'0' || name[index] > L'9') {
      return false;
    }
  }
  return true;
}

void RemoveTemporaryExportLogs(const std::wstring& temporary_directory,
                               const Logger& logger,
                               std::vector<CleanupError>* errors) {
  WIN32_FIND_DATAW find_data = {};
  const std::wstring search_pattern = JoinPath(
      temporary_directory, std::wstring(kTemporaryExportPrefix) + L"*");
  HANDLE raw_find_handle = ::FindFirstFileW(search_pattern.c_str(), &find_data);
  if (raw_find_handle == INVALID_HANDLE_VALUE) {
    const DWORD win32_error = ::GetLastError();
    if (win32_error != ERROR_FILE_NOT_FOUND &&
        win32_error != ERROR_PATH_NOT_FOUND) {
      const CleanupError error{CleanupStage::kEnumerateDirectory,
                               temporary_directory, win32_error};
      errors->push_back(error);
      logger.WriteError(error);
    }
    return;
  }
  const ScopedFindHandle find_handle(raw_find_handle);

  do {
    const std::wstring name = find_data.cFileName;
    if (!IsTemporaryExportName(name)) {
      continue;
    }

    const std::wstring candidate = JoinPath(temporary_directory, name);
    std::wstring absolute_candidate;
    CleanupError error{};
    if (!MakeAbsoluteLexicalPath(candidate, &absolute_candidate, &error)) {
      errors->push_back(error);
      logger.WriteError(error);
      continue;
    }
    if (!IsStrictChildPath(temporary_directory, absolute_candidate)) {
      error = {CleanupStage::kValidatePath, absolute_candidate,
               ERROR_ACCESS_DENIED};
      errors->push_back(error);
      logger.WriteError(error);
      continue;
    }
    RemoveKnownPath(absolute_candidate, logger, errors);
  } while (::FindNextFileW(raw_find_handle, &find_data));

  const DWORD find_error = ::GetLastError();
  if (find_error != ERROR_NO_MORE_FILES) {
    const CleanupError error{CleanupStage::kEnumerateDirectory,
                             temporary_directory, find_error};
    errors->push_back(error);
    logger.WriteError(error);
  }
}

struct Options {
  std::wstring sid;
};

bool ParseOption(const std::wstring& argument, const std::wstring& name,
                 std::wstring* value) {
  const std::wstring prefix = L"/" + name + L"=";
  if (!StartsWithIgnoreCase(argument, prefix)) {
    return false;
  }
  *value = argument.substr(prefix.size());
  return true;
}

bool ParseOptions(int argument_count, wchar_t* arguments[], Options* options,
                  CleanupError* error) {
  for (int index = 1; index < argument_count; ++index) {
    const std::wstring argument = arguments[index];
    if (ParseOption(argument, L"USERSID", &options->sid)) {
      continue;
    }
    *error = {CleanupStage::kParseOptions, argument, ERROR_INVALID_PARAMETER};
    return false;
  }
  return true;
}

}  // namespace

int wmain(int argument_count, wchar_t* arguments[]) {
  Logger logger;
  CleanupError error{};
  Options options;
  if (!ParseOptions(argument_count, arguments, &options, &error)) {
    logger.WriteError(error);
    return ToProcessExitCode(ExitCodeForError(error));
  }

  std::wstring sid;
  if (!options.sid.empty()) {
    if (!CanonicalizeSid(options.sid, &sid, &error)) {
      logger.WriteError(error);
      return ToProcessExitCode(ExitCodeForError(error));
    }
  } else if (!GetInteractiveSessionSid(&sid, &error)) {
    logger.WriteError(error);
    return ToProcessExitCode(ExitCodeForError(error));
  }
  logger.Write(L"Target user SID: " + sid);

  std::wstring profile_path;
  if (!ReadProfilePath(sid, &profile_path, &error)) {
    logger.WriteError(error);
    return ToProcessExitCode(ExitCodeForError(error));
  }

  std::wstring absolute_profile;
  if (!MakeAbsoluteLexicalPath(profile_path, &absolute_profile, &error)) {
    logger.WriteError(error);
    return ToProcessExitCode(ExitCodeForError(error));
  }

  ScopedRegistryKey user_registry;
  if (!OpenUserRegistry(sid, absolute_profile, &user_registry, &error)) {
    logger.WriteError(error);
    return ToProcessExitCode(ExitCodeForError(error));
  }

  std::wstring roaming_app_data;
  if (!ResolveRoamingAppData(user_registry.get(), absolute_profile,
                             &roaming_app_data, &error)) {
    logger.WriteError(error);
    return ToProcessExitCode(ExitCodeForError(error));
  }
  logger.Write(L"Resolved Roaming AppData: " + roaming_app_data);

  std::wstring temporary_directory;
  if (!ResolveTemporaryDirectory(user_registry.get(), absolute_profile,
                                 &temporary_directory, &error)) {
    logger.WriteError(error);
    return ToProcessExitCode(ExitCodeForError(error));
  }
  logger.Write(L"Resolved temporary directory: " + temporary_directory);

  const std::vector<std::wstring> relative_paths = {
      L"TrustTunnel", L"Adguard Software Limited\\TrustTunnel"};
  std::vector<CleanupError> errors;
  for (const std::wstring& relative_path : relative_paths) {
    const std::wstring candidate = JoinPath(roaming_app_data, relative_path);
    std::wstring target_path;
    if (!MakeAbsoluteLexicalPath(candidate, &target_path, &error)) {
      errors.push_back(error);
      logger.WriteError(error);
      continue;
    }
    if (!IsStrictChildPath(roaming_app_data, target_path)) {
      error = {CleanupStage::kValidatePath, target_path, ERROR_ACCESS_DENIED};
      errors.push_back(error);
      logger.WriteError(error);
      continue;
    }
    RemoveKnownPath(target_path, logger, &errors);
  }

  RemoveTemporaryExportLogs(temporary_directory, logger, &errors);
  return ToProcessExitCode(ExitCodeForErrors(errors));
}
