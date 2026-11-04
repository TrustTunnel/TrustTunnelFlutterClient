#ifndef VPN_PLUGIN_LINUX_VPN_ENGINE_H_
#define VPN_PLUGIN_LINUX_VPN_ENGINE_H_

#include <atomic>
#include <string>
#include <thread>

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

// Fired from worker threads; caller must marshal to main thread if needed.
typedef void (*VpnEngineStateCallback)(void* user_data, int state);

// Stub Linux VPN engine. Free of GTK/GLib for standalone unit testing.
class LinuxVpnEngine {
 public:
  LinuxVpnEngine(int connect_delay_ms, VpnEngineStateCallback callback, void* user_data);
  ~LinuxVpnEngine();

  LinuxVpnEngine(const LinuxVpnEngine&) = delete;
  LinuxVpnEngine& operator=(const LinuxVpnEngine&) = delete;

  void Start(const char* /*config*/);
  void Stop();
  int GetCurrentState() const { return state_; }

  // Decodes standard and URL-safe base64; returns false on malformed input.
  static bool DecodeDeepLink(const char* uri, std::string* payload);

 private:
  void WorkerMain();

  const int connect_delay_ms_;
  VpnEngineStateCallback callback_;
  void* user_data_;

  std::atomic<int> state_;
  std::atomic<bool> cancel_;
  std::thread worker_;
};

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_LINUX_VPN_ENGINE_H_
