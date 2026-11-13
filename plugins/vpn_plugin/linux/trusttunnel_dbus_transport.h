#ifndef VPN_PLUGIN_TRUSTTUNNEL_DBUS_TRANSPORT_H_
#define VPN_PLUGIN_TRUSTTUNNEL_DBUS_TRANSPORT_H_

#include "trusttunnel_transport.h"

#include <gio/gio.h>

namespace vpn_plugin {

// TrustTunnel transport backed by the D-Bus system bus daemon
// (com.adguard.TrustTunnel, interface com.adguard.TrustTunnel.Vpn1).
//
// Method calls are synchronous and run on the Flutter platform thread (the
// GObject Pigeon generator does not implement @TaskQueue), so each call uses
// an explicit bounded timeout. Daemon signals and name-owner changes are
// delivered on the default GLib main context (the UI thread): signals are
// subscribed through the GDBusProxy (which tracks the daemon's name owner,
// so the subscription survives a daemon restart), and losing the name owner
// is reported as the disconnected state, since a restarted daemon cannot
// keep the previous VPN session alive.
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
  static void OnProxySignal(GDBusProxy* proxy,
                            const gchar* sender_name,
                            const gchar* signal_name,
                            GVariant* parameters,
                            gpointer user_data);
  static void OnNameOwnerChanged(GObject* object,
                                 GParamSpec* pspec,
                                 gpointer user_data);

  void ConnectProxySignals();
  void HandleNameOwnerChanged();

  GDBusProxy* proxy_ = nullptr;
  gulong signal_handler_id_ = 0;
  gulong owner_handler_id_ = 0;
  gboolean handlers_set_ = FALSE;
  gboolean signals_connected_ = FALSE;
  // Whether the daemon owned the bus name at the last check; used to detect
  // the disappearance exactly once.
  gboolean had_owner_ = FALSE;
  TransportHandlers handlers_;
};

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_TRUSTTUNNEL_DBUS_TRANSPORT_H_
