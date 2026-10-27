// Shared per-user Run registration and login-window preference handling.
// Callers supply HKCU or the target user's registry root and hive type. User
// hives use KTM transactions; process-private application hives do not support
// them. Uninstall preserves other executables' Run entries and the preference.

#include "launch_at_login_registry.h"

#include <ktmw32.h>
#include <shellapi.h>

#include <string>

namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"TrustTunnel";
constexpr wchar_t kSettingsKey[] = L"Software\\AdGuard\\TrustTunnel";
constexpr wchar_t kWindowPreference[] = L"open_main_window_on_login";
// Run commands are limited to 260 characters, including quotes and arguments.
constexpr size_t kMaxRunCommandLength = 260;
constexpr DWORD kExecutablePathCapacity = 32768;

class RegistryKey final {
 public:
  RegistryKey() = default;
  ~RegistryKey() {
    if (value != nullptr) {
      ::RegCloseKey(value);
    }
  }
  RegistryKey(const RegistryKey&) = delete;
  RegistryKey& operator=(const RegistryKey&) = delete;

  HKEY value = nullptr;
};

class RegistryTransaction final {
 public:
  explicit RegistryTransaction(bool enabled = true)
      : value(enabled
                  ? ::CreateTransaction(nullptr, nullptr, 0, 0, 0, 0, nullptr)
                  : nullptr) {}
  ~RegistryTransaction() {
    if (value != nullptr && value != INVALID_HANDLE_VALUE) {
      // Closing an uncommitted transaction rolls back all its registry writes.
      ::CloseHandle(value);
    }
  }
  RegistryTransaction(const RegistryTransaction&) = delete;
  RegistryTransaction& operator=(const RegistryTransaction&) = delete;

  LSTATUS Commit() const {
    return value == nullptr || ::CommitTransaction(value)
               ? ERROR_SUCCESS
               : static_cast<LSTATUS>(::GetLastError());
  }

  HANDLE value;
};

LSTATUS OpenKey(HKEY root, const wchar_t* path, REGSAM access, RegistryKey& key,
                HANDLE transaction = nullptr) {
  return transaction == nullptr
             ? ::RegOpenKeyExW(root, path, 0, access, &key.value)
             : ::RegOpenKeyTransactedW(root, path, 0, access, &key.value,
                                       transaction, nullptr);
}

LSTATUS CreateKey(HKEY root, const wchar_t* path, RegistryKey& key,
                  HANDLE transaction) {
  return transaction == nullptr
             ? ::RegCreateKeyExW(root, path, 0, nullptr,
                                 REG_OPTION_NON_VOLATILE, KEY_SET_VALUE,
                                 nullptr, &key.value, nullptr)
             : ::RegCreateKeyTransactedW(root, path, 0, nullptr,
                                         REG_OPTION_NON_VOLATILE, KEY_SET_VALUE,
                                         nullptr, &key.value, nullptr,
                                         transaction, nullptr);
}

LSTATUS ReadEnabledInTransaction(HKEY root, bool& enabled,
                                 HANDLE transaction = nullptr) {
  enabled = false;
  RegistryKey key;
  LSTATUS status = OpenKey(root, kRunKey, KEY_QUERY_VALUE, key, transaction);
  if (status == ERROR_FILE_NOT_FOUND) {
    return ERROR_SUCCESS;
  }
  if (status != ERROR_SUCCESS) {
    return status;
  }
  DWORD size = 0;
  status = ::RegQueryValueExW(key.value, kRunValue, nullptr, nullptr, nullptr,
                              &size);
  if (status == ERROR_FILE_NOT_FOUND) {
    return ERROR_SUCCESS;
  }
  enabled = status == ERROR_SUCCESS;
  return status;
}

LSTATUS ReadWindowPreferenceInTransaction(HKEY root, bool& enabled,
                                          HANDLE transaction = nullptr) {
  enabled = false;
  RegistryKey key;
  LSTATUS status =
      OpenKey(root, kSettingsKey, KEY_QUERY_VALUE, key, transaction);
  if (status == ERROR_FILE_NOT_FOUND) {
    return ERROR_SUCCESS;
  }
  if (status != ERROR_SUCCESS) {
    return status;
  }
  DWORD type = 0;
  DWORD value = 0;
  DWORD size = sizeof(value);
  status = ::RegQueryValueExW(key.value, kWindowPreference, nullptr, &type,
                              reinterpret_cast<BYTE*>(&value), &size);
  if (status == ERROR_FILE_NOT_FOUND) {
    return ERROR_SUCCESS;
  }
  if (status != ERROR_SUCCESS) {
    return status;
  }
  if (type != REG_DWORD || size != sizeof(value) || value > 1) {
    return ERROR_INVALID_DATA;
  }
  enabled = value != 0;
  return ERROR_SUCCESS;
}

LSTATUS WriteRunCommand(HKEY root, bool open_window, HANDLE transaction) {
  std::wstring path(kExecutablePathCapacity, L'\0');
  const DWORD length =
      ::GetModuleFileNameW(nullptr, path.data(), kExecutablePathCapacity);
  if (length == 0) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  if (length >= kExecutablePathCapacity) {
    return ERROR_FILENAME_EXCED_RANGE;
  }
  path.resize(length);
  const std::wstring command =
      L"\"" + path + L"\" --autostart=" + (open_window ? L"window" : L"tray");
  if (command.size() > kMaxRunCommandLength) {
    return ERROR_FILENAME_EXCED_RANGE;
  }

  RegistryKey key;
  const LSTATUS status = CreateKey(root, kRunKey, key, transaction);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  return ::RegSetValueExW(
      key.value, kRunValue, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
}

}  // namespace

namespace windows_launch_at_login {

LSTATUS ReadEnabled(HKEY root, bool& enabled) {
  return ReadEnabledInTransaction(root, enabled);
}

LSTATUS ReadWindowPreference(HKEY root, bool& enabled) {
  return ReadWindowPreferenceInTransaction(root, enabled);
}

LSTATUS SetEnabled(HKEY root, bool enabled,
                   windows_user_context::RegistryHiveType hive_type) {
  RegistryTransaction transaction(
      hive_type == windows_user_context::RegistryHiveType::kUser);
  if (transaction.value == INVALID_HANDLE_VALUE) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  LSTATUS status;
  if (enabled) {
    bool open_window = false;
    status =
        ReadWindowPreferenceInTransaction(root, open_window, transaction.value);
    if (status == ERROR_SUCCESS) {
      status = WriteRunCommand(root, open_window, transaction.value);
    }
  } else {
    RegistryKey key;
    status = OpenKey(root, kRunKey, KEY_SET_VALUE, key, transaction.value);
    if (status == ERROR_SUCCESS) {
      status = ::RegDeleteValueW(key.value, kRunValue);
    }
    if (status == ERROR_FILE_NOT_FOUND) {
      status = ERROR_SUCCESS;
    }
  }
  if (status != ERROR_SUCCESS) {
    return status;
  }
  return transaction.Commit();
}

LSTATUS SetWindowPreference(HKEY root, bool enabled) {
  RegistryTransaction transaction;
  if (transaction.value == INVALID_HANDLE_VALUE) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  bool launch_enabled = false;
  LSTATUS status =
      ReadEnabledInTransaction(root, launch_enabled, transaction.value);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  if (launch_enabled) {
    status = WriteRunCommand(root, enabled, transaction.value);
    if (status != ERROR_SUCCESS) {
      return status;
    }
  }
  RegistryKey key;
  status = CreateKey(root, kSettingsKey, key, transaction.value);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  const DWORD value = enabled ? 1 : 0;
  status =
      ::RegSetValueExW(key.value, kWindowPreference, 0, REG_DWORD,
                       reinterpret_cast<const BYTE*>(&value), sizeof(value));
  if (status != ERROR_SUCCESS) {
    return status;
  }
  // Both values become visible together. Any earlier failure leaves both
  // intact.
  return transaction.Commit();
}

namespace {
LSTATUS NormalizeExecutable(const std::wstring& input, std::wstring& path) {
  // Run registrations created by this app always contain an absolute path.
  if (input.size() < 3 ||
      !((input[1] == L':' && (input[2] == L'\\' || input[2] == L'/')) ||
        (input[0] == L'\\' && input[1] == L'\\'))) {
    return ERROR_BAD_PATHNAME;
  }
  std::wstring buffer(kExecutablePathCapacity, L'\0');
  DWORD size = ::GetFullPathNameW(input.c_str(), kExecutablePathCapacity,
                                  buffer.data(), nullptr);
  if (size == 0) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  if (size >= kExecutablePathCapacity) {
    return ERROR_FILENAME_EXCED_RANGE;
  }
  buffer.resize(size);
  path = buffer;
  buffer.resize(kExecutablePathCapacity);
  size =
      ::GetLongPathNameW(path.c_str(), buffer.data(), kExecutablePathCapacity);
  if (size > 0 && size < kExecutablePathCapacity) {
    buffer.resize(size);
    path = buffer;
  }
  return ERROR_SUCCESS;
}
}  // namespace

LSTATUS RemoveForExecutable(HKEY root, const std::wstring& executable,
                            windows_user_context::RegistryHiveType hive_type) {
  std::wstring expected;
  LSTATUS status = NormalizeExecutable(executable, expected);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  RegistryTransaction transaction(
      hive_type == windows_user_context::RegistryHiveType::kUser);
  if (transaction.value == INVALID_HANDLE_VALUE) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  RegistryKey key;
  status = OpenKey(root, kRunKey, KEY_QUERY_VALUE | KEY_SET_VALUE, key,
                   transaction.value);
  if (status == ERROR_FILE_NOT_FOUND) {
    return ERROR_SUCCESS;
  }
  if (status != ERROR_SUCCESS) {
    return status;
  }
  DWORD bytes = 0;
  status = ::RegGetValueW(key.value, nullptr, kRunValue, RRF_RT_REG_SZ, nullptr,
                          nullptr, &bytes);
  if (status == ERROR_FILE_NOT_FOUND) {
    return ERROR_SUCCESS;
  }
  if (status != ERROR_SUCCESS) {
    return status;
  }
  if (bytes < sizeof(wchar_t) || bytes % sizeof(wchar_t) != 0) {
    return ERROR_INVALID_DATA;
  }
  std::wstring command(bytes / sizeof(wchar_t), L'\0');
  status = ::RegGetValueW(key.value, nullptr, kRunValue, RRF_RT_REG_SZ, nullptr,
                          command.data(), &bytes);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  int count = 0;
  LPWSTR* arguments = ::CommandLineToArgvW(command.c_str(), &count);
  if (arguments == nullptr) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  std::wstring registered;
  status = count == 0 ? ERROR_INVALID_DATA
                      : NormalizeExecutable(arguments[0], registered);
  ::LocalFree(arguments);
  // An unrecognised command is never permission to delete somebody else's
  // entry.
  if (status != ERROR_SUCCESS) {
    return status;
  }
  if (::CompareStringOrdinal(expected.c_str(), -1, registered.c_str(), -1,
                             TRUE) != CSTR_EQUAL) {
    return ERROR_SUCCESS;
  }
  status = ::RegDeleteValueW(key.value, kRunValue);
  if (status != ERROR_SUCCESS && status != ERROR_FILE_NOT_FOUND) {
    return status;
  }
  return transaction.Commit();
}

}  // namespace windows_launch_at_login
