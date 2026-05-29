#include "vpn_plugin.h"

#include <cstdio>
#include <filesystem>
#include <shellapi.h>
#include <ShlObj.h>
#include <appmodel.h>

#include "vpn/vpn_easy.h"
#include "vpn/vpn_easy_service.h"

namespace vpn_plugin {

// Minimal Windows-native logging (replaces common/logger.h dependency).
// OutputDebugStringA sends to the debugger; for production MSIX builds
// these messages appear in tools like DebugView or ETW traces.
static void LogError(const char* fmt, ...) {
  char buf[512];
  va_list args;
  va_start(args, fmt);
  int n = vsnprintf(buf, sizeof(buf), fmt, args);
  va_end(args);
  if (n > 0) {
    OutputDebugStringA(buf);
    OutputDebugStringA("\n");
  }
}

// ---------------------------------------------------------------------------
// MSIX helpers
// ---------------------------------------------------------------------------

/// Returns true when the process is running inside an MSIX/AppX container.
static bool IsRunningInMsixPackage() {
  UINT32 len = 0;
  // Call with null buffer to probe: ERROR_INSUFFICIENT_BUFFER (122) means
  // the process HAS package identity; APPMODEL_ERROR_NO_PACKAGE (15700)
  // means it's an unpackaged Win32 process.
  LONG result = GetCurrentPackageFullName(&len, nullptr);
  return (result == ERROR_INSUFFICIENT_BUFFER);
}

/// Returns the directory containing the running executable.
/// Uses dynamic allocation to avoid MAX_PATH truncation.
static std::filesystem::path GetExeDir() {
  std::wstring exe_path;
  DWORD buf_size = MAX_PATH;
  do {
    exe_path.resize(buf_size);
    DWORD len = GetModuleFileNameW(nullptr, exe_path.data(), buf_size);
    if (len == 0) {
      LogError("GetModuleFileNameW failed (error: %lu)", GetLastError());
      return {};
    }
    if (len < buf_size) {
      exe_path.resize(len);
      break;
    }
    buf_size *= 2;
  } while (true);
  return std::filesystem::path(exe_path).parent_path();
}

/// Returns a writable directory for runtime data (logs, ring buffers).
///
/// MSIX: %ProgramData%\TrustTunnel\ (shared between app and SYSTEM service).
/// Otherwise: same directory as the executable.
static std::filesystem::path GetWritableAppDataPath() {
  if (IsRunningInMsixPackage()) {
    PWSTR programData = nullptr;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_ProgramData, 0, nullptr, &programData))) {
      std::filesystem::path p = std::filesystem::path(programData) / L"TrustTunnel";
      CoTaskMemFree(programData);
      std::error_code ec;
      std::filesystem::create_directories(p, ec);
      return p;
    }
  }
  return GetExeDir();
}

// --- vpn_easy C Callbacks ---

static void s_notify_state_changed(void* arg, int state) {
  auto* plugin = static_cast<VpnPlugin*>(arg);
  plugin->NotifyStateChanged(state);
}

static void s_notify_connection_info(void* arg, const char* json) {
  auto* plugin = static_cast<VpnPlugin*>(arg);
  if (json != nullptr) {
    plugin->NotifyConnectionInfo(std::string(json));
  }
}

// --- VpnEventStreamHandler ---

void VpnEventStreamHandler::SendEvent(const flutter::EncodableValue& event) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (sink_) {
    sink_->Success(event);
  } else {
    event_queue_.push(event);
  }
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
VpnEventStreamHandler::OnListenInternal(
    const flutter::EncodableValue* /*arguments*/,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  std::lock_guard<std::mutex> lock(mutex_);
  sink_ = std::move(events);
  while (!event_queue_.empty()) {
    sink_->Success(event_queue_.front());
    event_queue_.pop();
  }
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
VpnEventStreamHandler::OnCancelInternal(const flutter::EncodableValue* /*arguments*/) {
  std::lock_guard<std::mutex> lock(mutex_);
  sink_.reset();
  return nullptr;
}

// --- VpnPlugin ---

void VpnPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<VpnPlugin>(registrar);

  // Register IVpnManager with Pigeon generated handler
  IVpnManager::SetUp(registrar->messenger(), plugin.get());

  registrar->AddPlugin(std::move(plugin));
}

VpnPlugin::VpnPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      service_name_(L"TrustTunnelVPN"),
      pipe_name_(L"\\\\.\\pipe\\trusttunnel_vpn") {

  // Use writable path (MSIX-safe) for runtime data.
  ring_buffer_path_ = (GetWritableAppDataPath() / L"vpn_query_log.ring").string();

  // Setup Event Channel for State
  auto state_handler = std::make_unique<VpnEventStreamHandler>();
  state_handler_ = state_handler.get();
  state_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "vpn_plugin_event_channel",
      &flutter::StandardMethodCodec::GetInstance());
  state_channel_->SetStreamHandler(std::move(state_handler));

  // Setup Event Channel for Query Log
  auto query_log_handler = std::make_unique<VpnEventStreamHandler>();
  query_log_handler_ = query_log_handler.get();
  query_log_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "vpn_plugin_event_channel_query_log",
      &flutter::StandardMethodCodec::GetInstance());
  query_log_channel_->SetStreamHandler(std::move(query_log_handler));

  // Attach to the background service and replay persisted connection info.
  worker_.Post([this]() {
    AttachService();
    vpn_easy_service_read_all_connection_info(
        ring_buffer_path_.c_str(), s_notify_connection_info, this);
  });
}

VpnPlugin::~VpnPlugin() {
  // Tear down the pipe IO synchronously before the worker stops.
  worker_.Sync([]() {
    vpn_easy_service_detach();
  });
}

int32_t VpnPlugin::RunElevatedHelper(const std::wstring& params) {
  std::filesystem::path exe_dir = GetExeDir();
  std::wstring helper_exe = (exe_dir / L"service_installer.exe").wstring();

  SHELLEXECUTEINFOW sei = {};
  sei.cbSize = sizeof(sei);
  sei.fMask = SEE_MASK_NOCLOSEPROCESS;
  sei.lpVerb = L"runas";
  sei.lpFile = helper_exe.c_str();
  sei.lpParameters = params.c_str();
  sei.nShow = SW_HIDE;

  if (!ShellExecuteExW(&sei)) {
    DWORD err = GetLastError();
    if (err == ERROR_CANCELLED) {
      return VPN_EASY_SVC_ERR_ACCESS;
    }
    return VPN_EASY_SVC_ERR_OTHER;
  }

  DWORD wait_result = WaitForSingleObject(sei.hProcess, kServiceInstallTimeoutMs);
  if (wait_result == WAIT_TIMEOUT) {
    CloseHandle(sei.hProcess);
    return VPN_EASY_SVC_ERR_TIMED_OUT;
  }
  DWORD exit_code = 0;
  GetExitCodeProcess(sei.hProcess, &exit_code);
  CloseHandle(sei.hProcess);

  return static_cast<int32_t>(exit_code);
}

int32_t VpnPlugin::InstallService() {
  if (IsRunningInMsixPackage()) {
    // When running in MSIX, the service is managed by the platform (packaged service).
    // Installing isn't supported, the service is installed along with the package.
    return VPN_EASY_SVC_ERR_UNSUPPORTED;
  }
  std::filesystem::path exe_dir = GetExeDir();
  std::wstring service_exe = (exe_dir / L"vpn_easy_service.exe").wstring();
  // Use writable path (MSIX-safe) for the service log.
  std::wstring log_path = (GetWritableAppDataPath() / L"vpn_easy_service.log").wstring();
  std::wstring ring_buffer_path_w(ring_buffer_path_.begin(), ring_buffer_path_.end());

  // Build the command-line arguments for service_installer.exe:
  //   install <image_path> <logfile_path> <pipe_name> <name> <display_name> <description> <ring_buffer_path>
  std::wstring params = L"install";
  params += L" \"" + service_exe + L"\"";
  params += L" \"" + log_path + L"\"";
  params += L" \"" + pipe_name_ + L"\"";
  params += L" \"" + service_name_ + L"\"";
  params += L" \"TrustTunnel VPN Service\"";
  params += L" \"Provides VPN connectivity for the TrustTunnel client.\"";
  params += L" \"" + ring_buffer_path_w + L"\"";

  return RunElevatedHelper(params);
}

int32_t VpnPlugin::UninstallService() {
  if (IsRunningInMsixPackage()) {
    // When running in MSIX, the service is managed by the platform (packaged service).
    // Uninstalling isn't supported, the service is removed when the package is uninstalled.
    return VPN_EASY_SVC_ERR_UNSUPPORTED;
  }
  std::wstring params = L"uninstall \"" + service_name_ + L"\"";
  return RunElevatedHelper(params);
}

int32_t VpnPlugin::AttachService() {
  return vpn_easy_service_attach(
          service_name_.c_str(), pipe_name_.c_str(), 
          s_notify_state_changed, this, s_notify_connection_info, this);
}

int32_t VpnPlugin::StartService(const std::string& config) {
  return vpn_easy_service_start(
          service_name_.c_str(), pipe_name_.c_str(), config.c_str(),
          s_notify_state_changed, this, s_notify_connection_info, this);
}

std::optional<FlutterError> VpnPlugin::Start(const std::string& config) {
  worker_.Post([this, config = config]() {
    int32_t start_result = StartService(config);

    if (start_result == VPN_EASY_SVC_ERR_NO_SUCH_SERVICE) {
      int32_t install_result = InstallService();
      if (install_result != 0) {
        LogError("Failed to install VPN service (error code: %d)", install_result);
        return;
      }

      start_result = StartService(config);
    }

    if (start_result != 0) {
      LogError("Failed to start VPN service (error code: %d)", start_result);
      return;
    }
  });

  return std::nullopt;
}

std::optional<FlutterError> VpnPlugin::Stop() {
  worker_.Post([this]() {
    vpn_easy_service_stop(service_name_.c_str(), pipe_name_.c_str());
  });

  return std::nullopt;
}

std::optional<FlutterError> VpnPlugin::UpdateConfiguration(const std::string* /*config*/) {
  // Not used directly in Windows background service handling in this manner
  return std::nullopt;
}

ErrorOr<VpnManagerState> VpnPlugin::GetCurrentState() {
  return ErrorOr<VpnManagerState>(current_state_);
}

void VpnPlugin::NotifyStateChanged(int state) {
  dispatcher_.RunOnUIThread([this, state]() {
    VpnManagerState converted_state = static_cast<VpnManagerState>(state);
    current_state_ = converted_state;
    if (state_handler_) {
      state_handler_->SendEvent(flutter::EncodableValue(static_cast<int64_t>(converted_state)));
    }
  });
}

void VpnPlugin::NotifyConnectionInfo(const std::string& json) {
  dispatcher_.RunOnUIThread([this, json]() {
    if (query_log_handler_) {
      query_log_handler_->SendEvent(flutter::EncodableValue(json));
    }
  });
}

}  // namespace vpn_plugin
