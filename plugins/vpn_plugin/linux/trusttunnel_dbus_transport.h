#ifndef VPN_PLUGIN_TRUSTTUNNEL_DBUS_TRANSPORT_H_
#define VPN_PLUGIN_TRUSTTUNNEL_DBUS_TRANSPORT_H_

#include "trusttunnel_transport.h"

#include <gio/gio.h>

namespace vpn_plugin {

// TrustTunnel transport backed by the D-Bus system bus daemon
// (com.adguard.TrustTunnel, interface com.adguard.TrustTunnel.Vpn1).
// Method calls are synchronous and thread-safe (made from the Pigeon
// serial background queue); daemon signals are delivered on the default
// GLib main context (the UI thread).
class TrustTunnelDBusTransport : public TrustTunnelTransport {
 public:
  TrustTunnelDBusTransport() = default;
  ~TrustTunnelDBusTransport() override;

  TrustTunnelDBusTransport(const TrustTunnelDBusTransport&) = delete;
  TrustTunnelDBusTransport& operator=(const TrustTunnelDBusTransport&) = delete;

  bool Init() override;
  TransportCallResult Start(const std::string& config) override;
  TransportCallResult Stop() override;
  int GetState() override;
  void ClearLogs() override;
  void SetHandlers(TransportHandlers handlers) override;

 private:
  static void OnStateChanged(GDBusConnection* connection,
                             const gchar* sender_name,
                             const gchar* object_path,
                             const gchar* interface_name,
                             const gchar* signal_name,
                             GVariant* parameters,
                             gpointer user_data);
  static void OnConnectionInfo(GDBusConnection* connection,
                               const gchar* sender_name,
                               const gchar* object_path,
                               const gchar* interface_name,
                               const gchar* signal_name,
                               GVariant* parameters,
                               gpointer user_data);

  void SubscribeSignals();

  GDBusProxy* proxy_ = nullptr;
  guint subscription_state_ = 0;
  guint subscription_info_ = 0;
  gboolean handlers_set_ = FALSE;
  gboolean subscribed_ = FALSE;
  TransportHandlers handlers_;
};

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_TRUSTTUNNEL_DBUS_TRANSPORT_H_
