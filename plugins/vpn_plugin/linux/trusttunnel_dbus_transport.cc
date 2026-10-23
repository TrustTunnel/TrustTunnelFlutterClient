#include "trusttunnel_dbus_transport.h"

#include <utility>

namespace vpn_plugin {

namespace {

const char kBusName[] = "com.adguard.TrustTunnel";
const char kObjectPath[] = "/com/adguard/TrustTunnel";
const char kInterfaceName[] = "com.adguard.TrustTunnel.Vpn1";

constexpr guint32 kDaemonResultAlreadyRunning = 1;
constexpr guint32 kDaemonResultInvalidConfig = 2;

}  // namespace

TrustTunnelDBusTransport::~TrustTunnelDBusTransport() {
  if (proxy_ != nullptr && subscribed_) {
    g_dbus_connection_signal_unsubscribe(g_dbus_proxy_get_connection(proxy_),
                                         subscription_state_);
    g_dbus_connection_signal_unsubscribe(g_dbus_proxy_get_connection(proxy_),
                                         subscription_info_);
  }
  g_clear_object(&proxy_);
}

bool TrustTunnelDBusTransport::Init() {
  if (proxy_ != nullptr) {
    return true;
  }
  GError* error = nullptr;
  proxy_ = g_dbus_proxy_new_for_bus_sync(G_BUS_TYPE_SYSTEM,
                                         G_DBUS_PROXY_FLAGS_DO_NOT_LOAD_PROPERTIES,
                                         NULL,  // interface info is not needed here
                                         kBusName,
                                         kObjectPath,
                                         kInterfaceName,
                                         NULL,  // cancellable
                                         &error);
  if (proxy_ == nullptr) {
    g_error_free(error);
    return false;
  }
  // The engine sets the handlers before attaching; subscribe as soon as both
  // the proxy and the handlers are available.
  if (handlers_set_) {
    SubscribeSignals();
  }
  return true;
}

void TrustTunnelDBusTransport::SetHandlers(TransportHandlers handlers) {
  handlers_ = std::move(handlers);
  handlers_set_ = TRUE;
  if (proxy_ != nullptr) {
    SubscribeSignals();
  }
}

void TrustTunnelDBusTransport::SubscribeSignals() {
  if (subscribed_ || !handlers_set_) {
    return;
  }
  g_return_if_fail(proxy_ != nullptr);
  subscription_state_ = g_dbus_connection_signal_subscribe(g_dbus_proxy_get_connection(proxy_),
                                                           kBusName,
                                                           kInterfaceName,
                                                           "StateChanged",
                                                           kObjectPath,
                                                           NULL,
                                                           G_DBUS_SIGNAL_FLAGS_NONE,
                                                           OnStateChanged,
                                                           this,
                                                           nullptr);
  subscription_info_ = g_dbus_connection_signal_subscribe(g_dbus_proxy_get_connection(proxy_),
                                                          kBusName,
                                                          kInterfaceName,
                                                          "ConnectionInfo",
                                                          kObjectPath,
                                                          NULL,
                                                          G_DBUS_SIGNAL_FLAGS_NONE,
                                                          OnConnectionInfo,
                                                          this,
                                                          nullptr);
  subscribed_ = TRUE;
}

void TrustTunnelDBusTransport::OnStateChanged(GDBusConnection* /*connection*/,
                                              const gchar* /*sender_name*/,
                                              const gchar* /*object_path*/,
                                              const gchar* /*interface_name*/,
                                              const gchar* /*signal_name*/,
                                              GVariant* parameters,
                                              gpointer user_data) {
  if (parameters == nullptr || !g_variant_is_of_type(parameters, G_VARIANT_TYPE("(i)"))) {
    return;
  }
  auto* self = static_cast<TrustTunnelDBusTransport*>(user_data);
  gint32 state = 0;
  g_variant_get(parameters, "(i)", &state);
  if (self->handlers_.on_state != nullptr) {
    self->handlers_.on_state(static_cast<int>(state));
  }
}

void TrustTunnelDBusTransport::OnConnectionInfo(GDBusConnection* /*connection*/,
                                                const gchar* /*sender_name*/,
                                                const gchar* /*object_path*/,
                                                const gchar* /*interface_name*/,
                                                const gchar* /*signal_name*/,
                                                GVariant* parameters,
                                                gpointer user_data) {
  if (parameters == nullptr || !g_variant_is_of_type(parameters, G_VARIANT_TYPE("(s)"))) {
    return;
  }
  auto* self = static_cast<TrustTunnelDBusTransport*>(user_data);
  const gchar* json = nullptr;
  g_variant_get(parameters, "(&s)", &json);
  if (self->handlers_.on_connection_info != nullptr && json != nullptr) {
    self->handlers_.on_connection_info(json);
  }
}

TransportCallResult TrustTunnelDBusTransport::Start(const std::string& config) {
  if (proxy_ == nullptr) {
    return TransportCallResult::kUnavailable;
  }
  GVariant* reply = g_dbus_proxy_call_sync(proxy_,
                                           "Start",
                                           g_variant_new("(s)", config.c_str()),
                                           G_DBUS_CALL_FLAGS_NONE,
                                           -1,  // default timeout
                                           NULL,
                                           nullptr);
  if (reply == nullptr) {
    return TransportCallResult::kUnavailable;
  }
  guint32 error_code = 0;
  g_variant_get(reply, "(u)", &error_code);
  g_variant_unref(reply);
  if (error_code == kDaemonResultAlreadyRunning) {
    return TransportCallResult::kAlreadyRunning;
  }
  if (error_code == kDaemonResultInvalidConfig) {
    return TransportCallResult::kInvalidConfig;
  }
  return TransportCallResult::kSuccess;
}

TransportCallResult TrustTunnelDBusTransport::Stop() {
  if (proxy_ == nullptr) {
    return TransportCallResult::kUnavailable;
  }
  GVariant* reply = g_dbus_proxy_call_sync(proxy_,
                                           "Stop",
                                           NULL,
                                           G_DBUS_CALL_FLAGS_NONE,
                                           3000,  // bounded: stop posts a request
                                           NULL,
                                           nullptr);
  if (reply == nullptr) {
    return TransportCallResult::kUnavailable;
  }
  guint32 error_code = 0;
  g_variant_get(reply, "(u)", &error_code);
  g_variant_unref(reply);
  return error_code == 0 ? TransportCallResult::kSuccess : TransportCallResult::kUnavailable;
}

int TrustTunnelDBusTransport::GetState() {
  if (proxy_ == nullptr) {
    return -1;
  }
  GVariant* reply = g_dbus_proxy_call_sync(proxy_,
                                           "GetState",
                                           NULL,
                                           G_DBUS_CALL_FLAGS_NONE,
                                           -1,
                                           NULL,
                                           nullptr);
  if (reply == nullptr) {
    return -1;
  }
  gint32 state = -1;
  g_variant_get(reply, "(i)", &state);
  g_variant_unref(reply);
  return state;
}

void TrustTunnelDBusTransport::ClearLogs() {
  if (proxy_ == nullptr) {
    return;
  }
  GVariant* reply = g_dbus_proxy_call_sync(proxy_,
                                           "ClearLogs",
                                           NULL,
                                           G_DBUS_CALL_FLAGS_NONE,
                                           3000,
                                           NULL,
                                           nullptr);
  g_clear_pointer(&reply, g_variant_unref);
}

std::unique_ptr<TrustTunnelTransport> CreateTrustTunnelDBusTransport() {
  return std::make_unique<TrustTunnelDBusTransport>();
}

}  // namespace vpn_plugin
