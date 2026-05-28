#include "vpn_plugin.h"

#include <filesystem>
#include <shellapi.h>

#include "vpn/vpn_easy.h"
#include "vpn/vpn_easy_service.h"

#include "common/logger.h"

namespace vpn_plugin {

static ag::Logger g_logger{"VPN_PLUGIN"};

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

  // Resolve absolute paths matching native_vpn_impl.cpp
  wchar_t exe_path[MAX_PATH];
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::filesystem::path exe_dir = std::filesystem::path(exe_path).parent_path();
  ring_buffer_path_ = (exe_dir / L"vpn_query_log.ring").string();

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

  // Pre-load connection states
  vpn_easy_service_read_all_connection_info(
      ring_buffer_path_.c_str(), s_notify_connection_info, this);

  // Start the background event loop for offloading blocking operations.
  ev_thread_ = std::thread([this]() {
    ag::vpn_event_loop_run(ev_loop_.get());
  });
  ag::vpn_event_loop_dispatch_sync(ev_loop_.get(), nullptr, nullptr);

  // Attempt to attach if background service is already active.
  // Fire-and-forget: if it fails, Start() handles installing + starting fresh.
  ag::event_loop::submit(ev_loop_.get(), [this]() {
  AttachService();
  }).release();
}

VpnPlugin::~VpnPlugin() {
  // Tear down the pipe IO synchronously on the event loop thread before stopping.
  ag::event_loop::dispatch_sync(ev_loop_.get(), []() {
  vpn_easy_service_detach();
  });
  ag::vpn_event_loop_stop(ev_loop_.get());
  if (ev_thread_.joinable()) {
    ev_thread_.join();
  }
}

int32_t VpnPlugin::InstallService() {
  wchar_t exe_path[MAX_PATH];
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::filesystem::path exe_dir = std::filesystem::path(exe_path).parent_path();
  std::wstring service_exe = (exe_dir / L"vpn_easy_service.exe").wstring();
  std::wstring log_path = exe_dir / L"vpn_easy_service.log";
  std::wstring ring_buffer_path_w(ring_buffer_path_.begin(), ring_buffer_path_.end());
  std::wstring helper_exe = (exe_dir / L"service_installer.exe").wstring();

  // Build the command-line arguments for service_installer.exe:
  //   install <image_path> <logfile_path> <pipe_name> <name> <display_name> <description> <ring_buffer_path>
  std::wstring params = L"install";
  params += L" \"" + service_exe + L"\"";       // arg 1: image_path
  params += L" \"" + log_path + L"\"";           // arg 2: logfile_path
  params += L" \"" + pipe_name_ + L"\"";          // arg 3: pipe_name
  params += L" \"" + service_name_ + L"\"";       // arg 4: name
  params += L" \"TrustTunnel VPN Service\"";      // arg 5: display_name
  params += L" \"Provides VPN connectivity for the TrustTunnel client.\""; // arg 6: description
  params += L" \"" + ring_buffer_path_w + L"\"";  // arg 7: ring_buffer_path

  // Launch the helper with UAC elevation (runas verb triggers the consent prompt).
  // SEE_MASK_NOCLOSEPROCESS is required to get sei.hProcess back — without it,
  // hProcess is NULL and we can't wait for the process or get its exit code.
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

  // Wait for the elevated helper to finish.
  // With SEE_MASK_NOCLOSEPROCESS, hProcess is guaranteed valid when ShellExecuteExW returns TRUE.
  WaitForSingleObject(sei.hProcess, INFINITE);
  DWORD exit_code = 0;
  GetExitCodeProcess(sei.hProcess, &exit_code);
  CloseHandle(sei.hProcess);

  return static_cast<int32_t>(exit_code);
}

int32_t VpnPlugin::UninstallService() {
  wchar_t exe_path[MAX_PATH];
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::filesystem::path exe_dir = std::filesystem::path(exe_path).parent_path();
  std::wstring helper_exe = (exe_dir / L"service_installer.exe").wstring();

  // Build the command-line arguments for service_installer.exe:
  //   uninstall <name>
  std::wstring params = L"uninstall \"" + service_name_ + L"\"";

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

  // With SEE_MASK_NOCLOSEPROCESS, hProcess is guaranteed valid when ShellExecuteExW returns TRUE.
  WaitForSingleObject(sei.hProcess, INFINITE);
  DWORD exit_code = 0;
  GetExitCodeProcess(sei.hProcess, &exit_code);
  CloseHandle(sei.hProcess);
  return static_cast<int32_t>(exit_code);
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
  ag::event_loop::submit(ev_loop_.get(), [this, config = config]() {
  int32_t start_result = StartService(config);

  if (start_result == VPN_EASY_SVC_ERR_NO_SUCH_SERVICE) {
    int32_t install_result = InstallService();
    if (install_result != 0) {
        errlog(g_logger, "Failed to install VPN service (error code: {})", install_result);
        return;
    }

    start_result = StartService(config);
  }

  if (start_result != 0) {
      errlog(g_logger, "Failed to start VPN service (error code: {})", start_result);
      return;
  }
  }).release();

  return std::nullopt;
}

std::optional<FlutterError> VpnPlugin::Stop() {
  ag::event_loop::submit(ev_loop_.get(), [this]() {
    vpn_easy_service_stop(service_name_.c_str(), pipe_name_.c_str());
  }).release();

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
