#ifndef VPN_PLUGIN_TRUSTTUNNEL_TRANSPORT_H_
#define VPN_PLUGIN_TRUSTTUNNEL_TRANSPORT_H_

#include <functional>
#include <memory>
#include <string>

namespace vpn_plugin {

// "Disconnected" value shared by the daemon protocol, VpnEngineState and the
// Pigeon VpnManagerState enum (all use 0 for disconnected).
static constexpr int kVpnStateDisconnected = 0;

// Result of an engine-issued Start/Stop request to the VPN daemon.
enum class TransportCallResult {
  kSuccess,
  kAlreadyRunning,
  kInvalidConfig,
  kUnavailable,
};

// Handlers invoked from the transport whenever the daemon publishes events.
// The transport delivers them on the default GLib main context (UI thread).
struct TransportHandlers {
  // VPN session state change; the value is a VpnEngineState.
  std::function<void(int state)> on_state;
  // JSON-encoded connection telemetry record (query log entry).
  std::function<void(const std::string& json)> on_connection_info;
};

// Transport interface between the VPN engine and the TrustTunnel daemon.
// Implemented over D-Bus in production (trusttunnel_dbus_transport.cc) and
// mocked in unit tests, so the engine logic stays hermetic.
//
// Threading: the Pigeon GObject generator has no @TaskQueue support, so the
// engine methods are called on the Flutter platform thread; every D-Bus call
// must therefore use a bounded timeout. Daemon events arrive on the main GLib
// context.
class TrustTunnelTransport {
 public:
  virtual ~TrustTunnelTransport() = default;

  // Attaches to the daemon. Returns false if it cannot be reached.
  virtual bool Init() = 0;

  // Starts a VPN session with the provided TOML configuration.
  virtual TransportCallResult Start(const std::string& config) = 0;

  // Requests the daemon to stop the running VPN session.
  virtual TransportCallResult Stop() = 0;

  // Current daemon-reported session state (VpnEngineState) or -1 on failure.
  virtual int GetState() = 0;

  // Requests the daemon to clear its accumulated logs.
  // No-op when the daemon does not support it.
  virtual void ClearLogs() = 0;

  // Replaces the event handlers. Call before Init().
  virtual void SetHandlers(TransportHandlers handlers) = 0;
};

// Creates the production D-Bus transport for the system bus daemon.
std::unique_ptr<TrustTunnelTransport> CreateTrustTunnelDBusTransport();

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_TRUSTTUNNEL_TRANSPORT_H_
