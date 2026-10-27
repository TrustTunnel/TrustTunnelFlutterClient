#include "trusttunnel_dbus_transport.h"

#include <utility>

namespace vpn_plugin {

namespace {

const char kBusName[] = "com.adguard.TrustTunnel";
const char kObjectPath[] = "/com/adguard/TrustTunnel";
const char kInterfaceName[] = "com.adguard.TrustTunnel.Vpn1";

constexpr guint32 kDaemonResultAlreadyRunning = 1;
constexpr guint32 kDaemonResultInvalidConfig = 2;

// Explicit bounded timeouts for the synchronous calls made from the Flutter
// platform thread: an unresponsive daemon must not freeze the GUI for the
// default GDBus timeout (~25 s).
constexpr gint kStartTimeoutMs = 5000;
constexpr gint kStopTimeoutMs = 3000;
constexpr gint kGetStateTimeoutMs = 2000;
constexpr gint kClearLogsTimeoutMs = 3000;

void LogDBusError(const char* operation, const GError* error) {
  g_warning("vpn_plugin: D-Bus %s failed: %s (domain %s, code %d)",
            operation,
            error != nullptr ? error->message : "unknown error",
            error != nullptr ? g_quark_to_string(error->domain) : "n/a",
            error != nullptr ? error->code : -1);
}

// Synchronous D-Bus call with an explicit timeout. Errors are logged and
// swallowed; the caller owns the returned variant (nullptr on failure).
GVariant* CallMethod(GDBusProxy* proxy,
                     const gchar* method,
                     GVariant* parameters,
                     gint timeout_ms) {
  GError* error = nullptr;
  GVariant* reply = g_dbus_proxy_call_sync(proxy,
                                           method,
                                           parameters,
                                           G_DBUS_CALL_FLAGS_NO_AUTO_START,
                                           timeout_ms,
                                           NULL,  // cancellable
                                           &error);
  if (reply == nullptr) {
    LogDBusError(method, error);
    g_error_free(error);
    return nullptr;
  }
  return reply;
}

// Validates the reply signature; a mismatch is logged and reported as failure
// instead of tripping a GLib assertion in g_variant_get.
bool ReplyHasSignature(GVariant* reply, const GVariantType* type, const gchar* method) {
  if (g_variant_is_of_type(reply, type)) {
    return true;
  }
  g_warning("vpn_plugin: unexpected %s reply signature: %s (expected %s)",
            method, g_variant_get_type_string(reply), g_variant_type_peek_string(type));
  return false;
}

}  // namespace

TrustTunnelDBusTransport::~TrustTunnelDBusTransport() {
  // The proxy signal handlers die together with the proxy object, which is
  // always released on the main thread (GObject dispose) — no explicit
  // unsubscription is required.
  g_clear_object(&proxy_);
}

bool TrustTunnelDBusTransport::Init() {
  if (proxy_ != nullptr) {
    return true;
  }
  GError* error = nullptr;
  proxy_ = g_dbus_proxy_new_for_bus_sync(G_BUS_TYPE_SYSTEM,
                                         static_cast<GDBusProxyFlags>(
                                             G_DBUS_PROXY_FLAGS_DO_NOT_LOAD_PROPERTIES |
                                             G_DBUS_PROXY_FLAGS_DO_NOT_AUTO_START),
                                         NULL,  // interface info is not needed here
                                         kBusName,
                                         kObjectPath,
                                         kInterfaceName,
                                         NULL,  // cancellable
                                         &error);
  if (proxy_ == nullptr) {
    LogDBusError("proxy creation", error);
    g_error_free(error);
    return false;
  }
  // The engine sets the handlers before attaching; connect the proxy signals
  // as soon as both the proxy and the handlers are available.
  if (handlers_set_) {
    ConnectProxySignals();
  }
  return true;
}

void TrustTunnelDBusTransport::SetHandlers(TransportHandlers handlers) {
  handlers_ = std::move(handlers);
  handlers_set_ = TRUE;
  if (proxy_ != nullptr) {
    ConnectProxySignals();
  }
}

void TrustTunnelDBusTransport::ConnectProxySignals() {
  if (signals_connected_ || !handlers_set_) {
    return;
  }
  g_return_if_fail(proxy_ != nullptr);
  signal_handler_id_ = g_signal_connect(proxy_, "g-signal",
                                        G_CALLBACK(OnProxySignal), this);
  owner_handler_id_ = g_signal_connect(proxy_, "notify::g-name-owner",
                                       G_CALLBACK(OnNameOwnerChanged), this);
  // A daemon that already owns the name must be "armed": its later
  // disappearance is what reports the disconnected state.
  had_owner_ = g_dbus_proxy_get_name_owner(proxy_) != nullptr;
  signals_connected_ = TRUE;
}

void TrustTunnelDBusTransport::OnProxySignal(GDBusProxy* /*proxy*/,
                                             const gchar* /*sender_name*/,
                                             const gchar* signal_name,
                                             GVariant* parameters,
                                             gpointer user_data) {
  auto* self = static_cast<TrustTunnelDBusTransport*>(user_data);
  if (g_strcmp0(signal_name, "StateChanged") == 0) {
    if (parameters != nullptr && g_variant_is_of_type(parameters, G_VARIANT_TYPE("(i)"))) {
      gint32 state = 0;
      g_variant_get(parameters, "(i)", &state);
      if (self->handlers_.on_state != nullptr) {
        self->handlers_.on_state(static_cast<int>(state));
      }
    }
    return;
  }
  if (g_strcmp0(signal_name, "ConnectionInfo") == 0) {
    if (parameters != nullptr && g_variant_is_of_type(parameters, G_VARIANT_TYPE("(s)"))) {
      const gchar* json = nullptr;
      g_variant_get(parameters, "(&s)", &json);
      if (self->handlers_.on_connection_info != nullptr && json != nullptr) {
        self->handlers_.on_connection_info(json);
      }
    }
    return;
  }
  // Other signals (e.g. NetworkReady) are not consumed by this client.
}

void TrustTunnelDBusTransport::OnNameOwnerChanged(GObject* /*object*/,
                                                  GParamSpec* /*pspec*/,
                                                  gpointer user_data) {
  static_cast<TrustTunnelDBusTransport*>(user_data)->HandleNameOwnerChanged();
}

void TrustTunnelDBusTransport::HandleNameOwnerChanged() {
  const gboolean has_owner = g_dbus_proxy_get_name_owner(proxy_) != nullptr;
  const gboolean was_owned = had_owner_;
  had_owner_ = has_owner;
  // A daemon restart cannot keep the VPN session alive, so the disappearance
  // of the name owner means the session is gone: report it once.
  if (!has_owner && was_owned && handlers_.on_state != nullptr) {
    handlers_.on_state(kVpnStateDisconnected);
  }
}

TransportCallResult TrustTunnelDBusTransport::Start(const std::string& config) {
  if (proxy_ == nullptr) {
    return TransportCallResult::kUnavailable;
  }
  // D-Bus strings must be valid UTF-8; reject early instead of tripping a
  // GLib assertion inside g_variant_new.
  if (!g_utf8_validate(config.c_str(), static_cast<gssize>(config.size()), nullptr)) {
    g_warning("vpn_plugin: Start config is not valid UTF-8");
    return TransportCallResult::kInvalidConfig;
  }
  GVariant* reply = CallMethod(proxy_, "Start", g_variant_new("(s)", config.c_str()),
                               kStartTimeoutMs);
  if (reply == nullptr) {
    return TransportCallResult::kUnavailable;
  }
  if (!ReplyHasSignature(reply, G_VARIANT_TYPE("(u)"), "Start")) {
    g_variant_unref(reply);
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
  GVariant* reply = CallMethod(proxy_, "Stop", NULL, kStopTimeoutMs);
  if (reply == nullptr) {
    return TransportCallResult::kUnavailable;
  }
  if (!ReplyHasSignature(reply, G_VARIANT_TYPE("(u)"), "Stop")) {
    g_variant_unref(reply);
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
  GVariant* reply = CallMethod(proxy_, "GetState", NULL, kGetStateTimeoutMs);
  if (reply == nullptr) {
    return -1;
  }
  if (!ReplyHasSignature(reply, G_VARIANT_TYPE("(i)"), "GetState")) {
    g_variant_unref(reply);
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
  GVariant* reply = CallMethod(proxy_, "ClearLogs", NULL, kClearLogsTimeoutMs);
  g_clear_pointer(&reply, g_variant_unref);
}

std::unique_ptr<TrustTunnelTransport> CreateTrustTunnelDBusTransport() {
  return std::make_unique<TrustTunnelDBusTransport>();
}

}  // namespace vpn_plugin
