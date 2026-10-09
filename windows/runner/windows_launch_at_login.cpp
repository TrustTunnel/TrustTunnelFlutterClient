#include "windows_launch_at_login.h"

#include <windows.h>

#include <flutter/standard_method_codec.h>
#include <ktmw32.h>

#include <cstdint>
#include <string>
#include <utility>
#include <variant>

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
  RegistryKey(const RegistryKey &) = delete;
  RegistryKey &operator=(const RegistryKey &) = delete;

  HKEY value = nullptr;
};

class RegistryTransaction final {
public:
  RegistryTransaction()
      : value(::CreateTransaction(nullptr, nullptr, 0, 0, 0, 0, nullptr)) {}
  ~RegistryTransaction() {
    if (value != INVALID_HANDLE_VALUE) {
      // Closing an uncommitted transaction rolls back all its registry writes.
      ::CloseHandle(value);
    }
  }
  RegistryTransaction(const RegistryTransaction &) = delete;
  RegistryTransaction &operator=(const RegistryTransaction &) = delete;

  HANDLE value;
};

LSTATUS OpenKey(const wchar_t *path, REGSAM access, RegistryKey &key,
                HANDLE transaction = nullptr) {
  return transaction == nullptr
             ? ::RegOpenKeyExW(HKEY_CURRENT_USER, path, 0, access, &key.value)
             : ::RegOpenKeyTransactedW(HKEY_CURRENT_USER, path, 0, access,
                                       &key.value, transaction, nullptr);
}

LSTATUS CreateKey(const wchar_t *path, RegistryKey &key, HANDLE transaction) {
  return ::RegCreateKeyTransactedW(
      HKEY_CURRENT_USER, path, 0, nullptr, REG_OPTION_NON_VOLATILE,
      KEY_SET_VALUE, nullptr, &key.value, nullptr, transaction, nullptr);
}

LSTATUS ReadEnabled(bool &enabled, HANDLE transaction = nullptr) {
  enabled = false;
  RegistryKey key;
  LSTATUS status = OpenKey(kRunKey, KEY_QUERY_VALUE, key, transaction);
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

LSTATUS ReadWindowPreference(bool &enabled, HANDLE transaction = nullptr) {
  enabled = false;
  RegistryKey key;
  LSTATUS status = OpenKey(kSettingsKey, KEY_QUERY_VALUE, key, transaction);
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
                              reinterpret_cast<BYTE *>(&value), &size);
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

LSTATUS WriteRunCommand(bool open_window, HANDLE transaction) {
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
  const LSTATUS status = CreateKey(kRunKey, key, transaction);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  return ::RegSetValueExW(
      key.value, kRunValue, 0, REG_SZ,
      reinterpret_cast<const BYTE *>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
}

LSTATUS SetEnabled(bool enabled) {
  RegistryTransaction transaction;
  if (transaction.value == INVALID_HANDLE_VALUE) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  LSTATUS status;
  if (enabled) {
    bool open_window = false;
    status = ReadWindowPreference(open_window, transaction.value);
    if (status == ERROR_SUCCESS) {
      status = WriteRunCommand(open_window, transaction.value);
    }
  } else {
    RegistryKey key;
    status = OpenKey(kRunKey, KEY_SET_VALUE, key, transaction.value);
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
  return ::CommitTransaction(transaction.value)
             ? ERROR_SUCCESS
             : static_cast<LSTATUS>(::GetLastError());
}

LSTATUS SetWindowPreference(bool enabled) {
  RegistryTransaction transaction;
  if (transaction.value == INVALID_HANDLE_VALUE) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  bool launch_enabled = false;
  LSTATUS status = ReadEnabled(launch_enabled, transaction.value);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  if (launch_enabled) {
    status = WriteRunCommand(enabled, transaction.value);
    if (status != ERROR_SUCCESS) {
      return status;
    }
  }
  RegistryKey key;
  status = CreateKey(kSettingsKey, key, transaction.value);
  if (status != ERROR_SUCCESS) {
    return status;
  }
  const DWORD value = enabled ? 1 : 0;
  status =
      ::RegSetValueExW(key.value, kWindowPreference, 0, REG_DWORD,
                       reinterpret_cast<const BYTE *>(&value), sizeof(value));
  if (status != ERROR_SUCCESS) {
    return status;
  }
  // Both values become visible together. Any earlier failure leaves both
  // intact.
  return ::CommitTransaction(transaction.value)
             ? ERROR_SUCCESS
             : static_cast<LSTATUS>(::GetLastError());
}

} // namespace

WindowsLaunchAtLogin::WindowsLaunchAtLogin(flutter::BinaryMessenger *messenger)
    : channel_(
          std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
              messenger, "trusttunnel/launch_at_login",
              &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto &call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

WindowsLaunchAtLogin::~WindowsLaunchAtLogin() {
  channel_->SetMethodCallHandler(nullptr);
}

void WindowsLaunchAtLogin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto &method = call.method_name();
  const bool is_getter =
      method == "isEnabled" || method == "getOpenMainWindowOnLogin";
  const bool is_setter =
      method == "setEnabled" || method == "setOpenMainWindowOnLogin";
  if (!is_getter && !is_setter) {
    result->NotImplemented();
    return;
  }

  bool enabled = false;
  if (is_setter) {
    const auto *arguments =
        call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments())
                         : nullptr;
    const bool *value = nullptr;
    if (arguments != nullptr) {
      const auto item = arguments->find(flutter::EncodableValue("enabled"));
      if (item != arguments->end()) {
        value = std::get_if<bool>(&item->second);
      }
    }
    if (value == nullptr) {
      result->Error("argument-error", "Expected a boolean enabled argument");
      return;
    }
    enabled = *value;
  }

  LSTATUS status;
  if (method == "isEnabled") {
    status = ReadEnabled(enabled);
  } else if (method == "setEnabled") {
    status = SetEnabled(enabled);
  } else if (method == "getOpenMainWindowOnLogin") {
    status = ReadWindowPreference(enabled);
  } else {
    status = SetWindowPreference(enabled);
  }
  if (status != ERROR_SUCCESS) {
    const bool too_long = status == ERROR_FILENAME_EXCED_RANGE;
    result->Error(too_long ? "autostart-command-too-long" : "registry-error",
                  too_long
                      ? "The login command exceeds the Windows Run limit of "
                        "260 characters"
                      : "Failed to access Windows login settings: " + method,
                  flutter::EncodableValue(static_cast<int64_t>(status)));
    return;
  }
  if (is_getter) {
    result->Success(flutter::EncodableValue(enabled));
  } else {
    result->Success();
  }
}
