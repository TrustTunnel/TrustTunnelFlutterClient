#ifndef FLUTTER_PLUGIN_VPN_PLUGIN_H_
#define FLUTTER_PLUGIN_VPN_PLUGIN_H_

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <queue>
#include <string>

#include "runner/platform_api.g.h"
#include "ui_thread_dispatcher.h"

namespace vpn_plugin {

class VpnEventStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  VpnEventStreamHandler() = default;
  virtual ~VpnEventStreamHandler() = default;

  void SendEvent(const flutter::EncodableValue& event);

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override;

 private:
  std::mutex mutex_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::queue<flutter::EncodableValue> event_queue_;
};

class VpnPlugin : public flutter::Plugin, public IVpnManager {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  VpnPlugin(flutter::PluginRegistrarWindows* registrar);
  ~VpnPlugin() override;

  VpnPlugin(const VpnPlugin&) = delete;
  VpnPlugin& operator=(const VpnPlugin&) = delete;

  // IVpnManager implementation
  std::optional<FlutterError> Start(const std::string& config) override;
  std::optional<FlutterError> Stop() override;
  std::optional<FlutterError> UpdateConfiguration(const std::string* config) override;
  ErrorOr<VpnManagerState> GetCurrentState() override;

  // C-callbacks for vpn_easy
  void NotifyStateChanged(int state);
  void NotifyConnectionInfo(const std::string& json);

 private:
  int32_t InstallService();
  int32_t AttachService();
  int32_t StartService(const std::string& config);

  flutter::PluginRegistrarWindows* registrar_;
  UIThreadDispatcher dispatcher_;

  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> state_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> query_log_channel_;
  
  VpnEventStreamHandler* state_handler_ = nullptr;
  VpnEventStreamHandler* query_log_handler_ = nullptr;

  std::wstring service_name_;
  std::wstring pipe_name_;
  std::string ring_buffer_path_;

  bool is_started_ = false;
  VpnManagerState current_state_ = VpnManagerState::kDisconnected;
};

}  // namespace vpn_plugin

#endif  // FLUTTER_PLUGIN_VPN_PLUGIN_H_