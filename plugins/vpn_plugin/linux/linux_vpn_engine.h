#ifndef VPN_PLUGIN_LINUX_VPN_ENGINE_H_
#define VPN_PLUGIN_LINUX_VPN_ENGINE_H_

#include <atomic>
#include <functional>
#include <string>

#include "trusttunnel_transport.h"

namespace vpn_plugin {

// Matches Pigeon enum VpnManagerState (platform_api.g.h).
enum VpnEngineState {
  kEngineStateDisconnected = 0,
  kEngineStateConnecting = 1,
  kEngineStateConnected = 2,
  kEngineStateWaitingForRecovery = 3,
  kEngineStateRecovering = 4,
  kEngineStateWaitingForNetwork = 5,
};

// Fired from daemon signal handlers (GLib main context); the receiver must
// marshal to the threads it needs if required.
typedef void (*VpnEngineStateCallback)(void* user_data, int state);

// JSON connection telemetry listener, running on the GLib main context.
using ConnectionInfoSink = std::function<void(const std::string& json)>;

// Linux VPN engine backed by the TrustTunnel D-Bus daemon. Free of GTK
// specifics for standalone unit testing; the transport is injected, so
// tests run against a mock. The transport is not owned and must outlive
// the engine.
class LinuxVpnEngine {
 public:
  LinuxVpnEngine(TrustTunnelTransport* transport,
                 VpnEngineStateCallback callback,
                 void* user_data);
  ~LinuxVpnEngine();

  LinuxVpnEngine(const LinuxVpnEngine&) = delete;
  LinuxVpnEngine& operator=(const LinuxVpnEngine&) = delete;

  // Starts a VPN session. On failure returns false and fills the error message.
  bool Start(const std::string& config, std::string* error_message);
  // Requests the daemon to stop the session; the final DISCONNECTED state
  // is reported by the daemon afterwards.
  void Stop();
  int GetCurrentState() const { return state_; }

  // Registers the sink receiving JSON connection telemetry records.
  // The sink runs on the GLib main context.
  void SetConnectionInfoSink(ConnectionInfoSink sink);

 private:
  // Daemon event handlers (called on the GLib main context).
  void OnDaemonState(int state);
  void OnDaemonConnectionInfo(const std::string& json);

  TrustTunnelTransport* const transport_;
  VpnEngineStateCallback callback_;
  void* user_data_;
  ConnectionInfoSink connection_info_sink_;

  std::atomic<int> state_;
};

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_LINUX_VPN_ENGINE_H_
