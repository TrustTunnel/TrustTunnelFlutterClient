#include "vpn_plugin.h"

#include <filesystem>

#include "vpn/vpn_easy.h"
#include "vpn/vpn_easy_service.h"

namespace vpn_plugin {

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
  vpn_easy_read_all_connection_info(
      ring_buffer_path_.c_str(), s_notify_connection_info, this);

  // Attempt to attach if background service is already active
  int32_t attach_result = AttachService();
  if (attach_result == 0) {
      is_started_ = true;
  }
}

VpnPlugin::~VpnPlugin() {
  vpn_easy_service_detach();
}

int32_t VpnPlugin::InstallService() {
  wchar_t exe_path[MAX_PATH];
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::filesystem::path exe_dir = std::filesystem::path(exe_path).parent_path();
  std::wstring service_exe = (exe_dir / L"vpn_easy_service.exe").wstring();
  std::wstring log_path = exe_dir / L"vpn_easy_service.log";
  std::wstring ring_buffer_path_w(ring_buffer_path_.begin(), ring_buffer_path_.end());

  return vpn_easy_service_install(service_exe.c_str(), log_path.c_str(), pipe_name_.c_str(),
          service_name_.c_str(), L"TrustTunnel VPN Service",
          L"Provides VPN connectivity for the TrustTunnel client.", ring_buffer_path_w.c_str());
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
  int32_t start_result = StartService(config);

  if (start_result == VPN_EASY_SVC_ERR_NO_SUCH_SERVICE) {
    int32_t install_result = InstallService();
    if (install_result != 0) {
      return FlutterError("SERVICE_INSTALL", "Failed to install VPN service");
    }
    start_result = StartService(config);
  }

  if (start_result != 0) {
    return FlutterError("SERVICE_START", "Failed to start VPN service");
  }

  is_started_ = true;
  return std::nullopt;
}

std::optional<FlutterError> VpnPlugin::Stop() {
  if (!is_started_) {
    return std::nullopt;
  }

  int32_t stop_result = vpn_easy_service_stop(service_name_.c_str(), pipe_name_.c_str());
  if (stop_result != 0) {
    // Just log / ignore, we fall through and mark as stopped
  }

  is_started_ = false;
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
