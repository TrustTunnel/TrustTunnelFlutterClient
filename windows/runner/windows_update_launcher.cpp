#include "windows_update_launcher.h"

#include <bcrypt.h>
#include <sddl.h>
#include <shellapi.h>
#include <shlobj.h>
#include <winver.h>

#include <array>
#include <cstdint>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <thread>
#include <vector>

namespace {
class ComApartment {
public:
  ComApartment()
      : initialized_(
            SUCCEEDED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) {}

  ~ComApartment() {
    if (initialized_) {
      CoUninitialize();
    }
  }

private:
  bool initialized_;
};

class Handle {
public:
  explicit Handle(HANDLE value = nullptr) : value_(value) {}

  ~Handle() {
    const bool valid_handle = value_ && value_ != INVALID_HANDLE_VALUE;

    if (valid_handle) {
      CloseHandle(value_);
    }
  }

  HANDLE get() const { return value_; }

private:
  HANDLE value_;
};

std::wstring Wide(const std::string &value) {
  const int length =
      MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), nullptr, 0);

  if (length <= 0) {
    throw std::runtime_error("Invalid UTF-8 argument");
  }

  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), length);
  return result;
}

std::string Hex(const unsigned char *bytes, size_t size) {
  std::ostringstream stream;
  for (size_t i = 0; i < size; ++i) {
    stream << std::hex << std::setfill('0') << std::setw(2)
           << static_cast<unsigned>(bytes[i]);
  }
  return stream.str();
}

std::string Text(const flutter::EncodableMap &args, const char *key) {
  const flutter::EncodableMap::const_iterator entry =
      args.find(flutter::EncodableValue(key));

  if (entry == args.end()) {
    throw std::runtime_error("Missing installer argument");
  }

  const std::string *value = std::get_if<std::string>(&entry->second);

  if (!value) {
    throw std::runtime_error("Invalid installer argument type");
  }

  return *value;
}

void Complete(const std::shared_ptr<WindowsUpdateLaunch> &state,
              const std::string &error, const std::string &message,
              bool keep_alive = false) {
  std::lock_guard<std::mutex> lock(state->mutex);
  state->error = error;
  state->message = message;
  state->completed = true;
  state->finished = !keep_alive;
}

bool ValidVersion(const std::wstring &path, const std::string &expected) {
  DWORD unused = 0;
  const DWORD size = GetFileVersionInfoSizeW(path.c_str(), &unused);

  if (!size) {
    return false;
  }

  std::vector<unsigned char> data(size);

  if (!GetFileVersionInfoW(path.c_str(), 0, size, data.data())) {
    return false;
  }
  VS_FIXEDFILEINFO *info = nullptr;
  UINT length = 0;
  const bool invalid_version_info =
      !VerQueryValueW(data.data(), L"\\", reinterpret_cast<void **>(&info),
                      &length) ||
      length < sizeof(VS_FIXEDFILEINFO) || info->dwSignature != 0xfeef04bd;

  if (invalid_version_info) {
    return false;
  }

  const std::string version =
      std::to_string(HIWORD(info->dwFileVersionMS)) + "." +
      std::to_string(LOWORD(info->dwFileVersionMS)) + "." +
      std::to_string(HIWORD(info->dwFileVersionLS));
  return version == expected;
}

std::string Hash(HANDLE file) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;

  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr,
                                  0) < 0) {
    throw std::runtime_error("BCryptOpenAlgorithmProvider failed");
  }

  BCRYPT_HASH_HANDLE hash = nullptr;
  const NTSTATUS created =
      BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0);

  if (created < 0) {
    BCryptCloseAlgorithmProvider(algorithm, 0);
    throw std::runtime_error("BCryptCreateHash failed");
  }

  std::array<unsigned char, 64 * 1024> buffer{};
  std::array<unsigned char, 32> digest{};
  bool valid = true;
  for (;;) {
    DWORD count = 0;

    if (!ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()),
                  &count, nullptr)) {
      valid = false;
      break;
    }

    if (!count) {
      break;
    }

    if (BCryptHashData(hash, buffer.data(), count, 0) < 0) {
      valid = false;
      break;
    }
  }

  if (valid) {
    valid = BCryptFinishHash(hash, digest.data(),
                             static_cast<ULONG>(digest.size()), 0) >= 0;
  }
  BCryptDestroyHash(hash);
  BCryptCloseAlgorithmProvider(algorithm, 0);

  if (!valid) {
    throw std::runtime_error("Unable to hash installer");
  }

  return Hex(digest.data(), digest.size());
}
} // namespace

std::string CreateUpdateOperation() {
  std::array<unsigned char, 16> bytes{};

  if (BCryptGenRandom(nullptr, bytes.data(), static_cast<ULONG>(bytes.size()),
                      BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0) {
    throw std::runtime_error("Unable to create update operation ID");
  }

  return Hex(bytes.data(), bytes.size());
}

std::shared_ptr<WindowsUpdateLaunch>
LaunchWindowsUpdate(const flutter::EncodableMap &arguments,
                    const std::string &operation) {
  std::shared_ptr<WindowsUpdateLaunch> state =
      std::make_shared<WindowsUpdateLaunch>();
  std::thread([state, arguments, operation]() {
    try {
      ComApartment apartment;
      const bool invalid_operation =
          Text(arguments, "operation") != operation || operation.empty();

      if (invalid_operation) {
        throw std::runtime_error("Installer operation does not match");
      }

      const std::wstring path = Wide(Text(arguments, "path"));
      const std::string version = Text(arguments, "version");
      const std::string expected_hash = Text(arguments, "sha256");
      const flutter::EncodableMap::const_iterator size_entry =
          arguments.find(flutter::EncodableValue("size"));

      if (size_entry == arguments.end()) {
        throw std::runtime_error("Missing installer size");
      }
      int64_t expected_size = 0;

      if (const int64_t *size64 = std::get_if<int64_t>(&size_entry->second)) {
        expected_size = *size64;
      } else if (const int32_t *size32 =
                     std::get_if<int32_t>(&size_entry->second)) {
        expected_size = *size32;
      } else {
        throw std::runtime_error("Invalid installer size type");
      }

      // Keep the file locked against writes and replacement through the launch.
      Handle file(CreateFileW(
          path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
          FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
      BY_HANDLE_FILE_INFORMATION info{};
      LARGE_INTEGER size{};
      const bool invalid_installer =
          file.get() == INVALID_HANDLE_VALUE ||
          !GetFileInformationByHandle(file.get(), &info) ||
          (info.dwFileAttributes &
           (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)) ||
          !GetFileSizeEx(file.get(), &size) || size.QuadPart != expected_size ||
          expected_size <= 0 || !ValidVersion(path, version) ||
          Hash(file.get()) != expected_hash;

      if (invalid_installer) {
        Complete(state, "damaged-file",
                 "Installer size, SHA-256 or version does not match");
        return;
      }

      const std::wstring event_name = L"Local\\TrustTunnel.UpdateReady." +
                                      std::to_wstring(GetCurrentProcessId()) +
                                      L"." + Wide(operation);
      PSECURITY_DESCRIPTOR descriptor = nullptr;

      if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
              L"D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)", SDDL_REVISION_1,
              &descriptor, nullptr)) {
        throw std::runtime_error("Unable to create event security descriptor");
      }
      SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), descriptor,
                                   FALSE};
      Handle event(CreateEventW(&security, TRUE, FALSE, event_name.c_str()));
      const DWORD event_error = GetLastError();
      LocalFree(descriptor);
      const bool invalid_event =
          !event.get() || event_error == ERROR_ALREADY_EXISTS;

      if (invalid_event) {
        throw std::runtime_error("Unable to create unique readiness event");
      }

      if (state->cancelled) {
        return;
      }

      const std::wstring parameters =
          L"/UPDATE=1 /INITIATORPID=" + std::to_wstring(GetCurrentProcessId()) +
          L" /OPERATION=" + Wide(operation) +
          L" /VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART";
      SHELLEXECUTEINFOW execute{};
      execute.cbSize = sizeof(execute);
      execute.fMask =
          SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC | SEE_MASK_FLAG_NO_UI;
      execute.lpVerb = L"runas";
      execute.lpFile = path.c_str();
      execute.lpParameters = parameters.c_str();
      execute.nShow = SW_HIDE;

      if (!ShellExecuteExW(&execute)) {
        const DWORD error = GetLastError();
        Complete(state,
                 error == ERROR_CANCELLED ? "permission-denied"
                                          : "installer-launch",
                 "ShellExecuteExW error=" + std::to_string(error));
        return;
      }

      Handle process(execute.hProcess);

      if (!process.get()) {
        throw std::runtime_error("Installer process handle is missing");
      }

      const ULONGLONG deadline = GetTickCount64() + 180000;
      HANDLE waits[] = {event.get(), process.get()};
      while (!state->cancelled && GetTickCount64() < deadline) {
        const DWORD result = WaitForMultipleObjects(2, waits, FALSE, 250);

        if (result == WAIT_OBJECT_0) {
          Complete(state, "", "", true);
          // Retain ownership until setup exits, including after the readiness
          // event.
          while (!state->cancelled &&
                 WaitForSingleObject(process.get(), 250) == WAIT_TIMEOUT) {
          }
          {
            std::lock_guard<std::mutex> lock(state->mutex);
            state->finished = true;
          }

          return;
        }

        if (result == WAIT_OBJECT_0 + 1) {
          DWORD exit_code = 0;
          GetExitCodeProcess(process.get(), &exit_code);
          Complete(state, "installer-exited",
                   "Installer exited before ready, code=" +
                       std::to_string(exit_code));
          return;
        }

        if (result == WAIT_FAILED) {
          throw std::runtime_error("Installer readiness wait failed");
        }
      }
      Complete(state, "installer-timeout", "Installer readiness timed out",
               true);
      // Reject late shutdown requests, but keep the operation reserved until
      // setup exits.
      while (!state->cancelled &&
             WaitForSingleObject(process.get(), 250) == WAIT_TIMEOUT) {
      }
      {
        std::lock_guard<std::mutex> lock(state->mutex);
        state->finished = true;
      }
    } catch (const std::exception &error) {
      Complete(state, "installer-launch", error.what());
    }
  }).detach();
  return state;
}

flutter::EncodableValue ReadWindowsUpdateResult() {
  PWSTR program_files = nullptr;

  if (FAILED(SHGetKnownFolderPath(FOLDERID_ProgramFiles, 0, nullptr,
                                  &program_files))) {
    throw std::runtime_error("Unable to locate protected installer result");
  }

  const std::wstring path = std::wstring(program_files) +
                            L"\\TrustTunnelInstaller\\update-result.ini";
  CoTaskMemFree(program_files);
  Handle file(CreateFileW(
      path.c_str(), GENERIC_READ,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr));

  if (file.get() == INVALID_HANDLE_VALUE) {
    const DWORD error = GetLastError();

    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
      return flutter::EncodableValue();
    }
    throw std::runtime_error("Unable to read installer result, error=" +
                             std::to_string(error));
  }

  BY_HANDLE_FILE_INFORMATION info{};
  LARGE_INTEGER size{};
  const bool invalid_result =
      !GetFileInformationByHandle(file.get(), &info) ||
      (info.dwFileAttributes &
       (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)) ||
      !GetFileSizeEx(file.get(), &size) || size.QuadPart <= 0 ||
      size.QuadPart > 65536;

  if (invalid_result) {
    throw std::runtime_error("Invalid installer result file");
  }

  std::string content(static_cast<size_t>(size.QuadPart), '\0');
  DWORD read = 0;
  const bool read_failed =
      !ReadFile(file.get(), content.data(), static_cast<DWORD>(content.size()),
                &read, nullptr) ||
      read != content.size();

  if (read_failed) {
    throw std::runtime_error("Unable to read installer result, error=" +
                             std::to_string(GetLastError()));
  }

  // Inno publishes UTF-8 without a BOM. The Windows INI API assumes ANSI.
  Wide(content);
  std::istringstream stream(content);
  std::string line;
  bool section = false;
  flutter::EncodableMap values;
  while (std::getline(stream, line)) {
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }

    if (!line.empty() && line.front() == '[') {
      section = line == "[update]";
      continue;
    }

    const std::string::size_type separator = line.find('=');

    if (section && separator != std::string::npos) {
      values[flutter::EncodableValue(line.substr(0, separator))] =
          flutter::EncodableValue(line.substr(separator + 1));
    }
  }

  if (Text(values, "schema") != "1") {
    throw std::runtime_error("Unsupported installer result schema");
  }

  return flutter::EncodableValue(values);
}
