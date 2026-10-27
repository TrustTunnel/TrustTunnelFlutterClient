#ifndef VPN_PLUGIN_LINUX_VPN_ENGINE_H_
#define VPN_PLUGIN_LINUX_VPN_ENGINE_H_

#include <atomic>
#include <cstdint>
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

// Upper bound for waiting out a daemon-side stop in Start().
static constexpr int kDefaultAlreadyRunningWaitTimeoutMs = 3000;

// Linux VPN engine backed by the TrustTunnel D-Bus daemon. Free of GTK
// specifics for standalone unit testing; the transport is injected, so
// tests run against a mock. The transport is not owned and must outlive
// the engine.
class LinuxVpnEngine {
 public:
  LinuxVpnEngine(TrustTunnelTransport* transport,
                 VpnEngineStateCallback callback,
                 void* user_data,
                 int already_running_wait_timeout_ms = kDefaultAlreadyRunningWaitTimeoutMs);
  ~LinuxVpnEngine();

  LinuxVpnEngine(const LinuxVpnEngine&) = delete;
  LinuxVpnEngine& operator=(const LinuxVpnEngine&) = delete;

  // Starts a VPN session. On failure returns false and fills the error message.
  // An ALREADY_RUNNING reply is resolved against the daemon state: a live
  // session is adopted; a session that is still being torn down is waited for
  // (bounded) and the start is retried once.
  bool Start(const std::string& config, std::string* error_message);
  // Requests the daemon to stop the session. Returns false when the daemon is
  // unreachable; in that case the cached state is left unchanged and the
  // daemon-reported DISCONNECTED never arrives.
  bool Stop(std::string* error_message);
  // Returns the current VPN state, synchronizing it with the daemon first
  // (a synchronous D-Bus call with a bounded timeout) so the initial
  // requestState() and later refreshes see an adopted session even when
  // Start() was never called from this client.
  int GetCurrentState();

  // Registers the sink receiving JSON connection telemetry records.
  // The sink runs on the GLib main context.
  void SetConnectionInfoSink(ConnectionInfoSink sink);

 private:
  // Daemon event handlers (called on the GLib main context).
  void OnDaemonState(int state);
  void OnDaemonConnectionInfo(const std::string& json);

  // Polls the daemon state until it reports DISCONNECTED or the timeout
  // expires; used to serialize a start behind a still-running stop.
  bool WaitForDaemonDisconnected(int timeout_ms);
  // Applies the daemon-reported state unless a newer daemon event (a signal
  // delivered while a synchronous call was in flight) has been applied already.
  void ApplyDaemonStateIfUnchanged(uint64_t generation);
  // Publishes DISCONNECTED after a failed start attempt.
  void RollBackToDisconnected();

  TrustTunnelTransport* const transport_;
  VpnEngineStateCallback callback_;
  void* user_data_;
  ConnectionInfoSink connection_info_sink_;

  std::atomic<int> state_;
  // Bumped on every accepted daemon state event (signals and GetState
  // refreshes alike). Single-threaded: only the main GLib context touches it.
  uint64_t state_generation_ = 0;
  // Upper bound for waiting out a daemon-side stop in Start(); injectable so
  // unit tests stay fast.
  int already_running_wait_timeout_ms_;
};

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_LINUX_VPN_ENGINE_H_
