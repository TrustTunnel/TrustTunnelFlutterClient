#include "include/vpn_plugin/vpn_plugin.h"

#include "linux_vpn_engine.h"
#include "platform_api.g.h"
#include "trusttunnel_dbus_transport.h"
#include "trusttunnel_deeplink.h"
#include "trusttunnel_transport.h"

#include <deque>
#include <string>

#define VPN_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), vpn_plugin_get_type(), VpnPlugin))

static const char kStateEventChannelName[] = "vpn_plugin_event_channel";
static const char kQueryLogEventChannelName[] = "vpn_plugin_event_channel_query_log";

// Maximum number of connection telemetry records kept for replay when
// a listener subscribes to the query-log EventChannel after they arrive.
static const size_t kConnectionInfoRingSize = 256;

struct _VpnPlugin {
  GObject parent_instance;

  // Owned manually: g_object_new does not run C++ constructors.
  vpn_plugin::TrustTunnelTransport* transport;
  vpn_plugin::LinuxVpnEngine* engine;

  FlEventChannel* state_event_channel;
  gboolean state_listening;

  FlEventChannel* query_log_event_channel;
  gboolean query_log_listening;
  // Connection telemetry records received before a listener attached.
  // Threading: both the producer (send_connection_info, called from GDBus
  // callbacks) and the consumers (replay_ring_idle, dispose) run on the main
  // GLib loop, so no locking is needed. If the D-Bus signals ever move to a
  // worker thread, guard this field with a mutex.
  std::deque<std::string>* connection_info_ring;

  FlBinaryMessenger* messenger;
};

G_DEFINE_TYPE(VpnPlugin, vpn_plugin, g_object_get_type())

// -------- VPN state (EventChannel "vpn_plugin_event_channel") --------

static void emit_vpn_state(VpnPlugin* self) {
  if (self->engine == nullptr || self->state_event_channel == NULL ||
      !self->state_listening) {
    return;
  }
  g_autoptr(FlValue) event = fl_value_new_int(self->engine->GetCurrentState());
  fl_event_channel_send(self->state_event_channel, event, NULL, NULL);
}

static gboolean emit_state_idle(gpointer user_data) {
  emit_vpn_state(VPN_PLUGIN(user_data));
  return G_SOURCE_REMOVE;
}

static void on_engine_state(void* user_data, int /*state*/) {
  g_idle_add_full(G_PRIORITY_DEFAULT, emit_state_idle, g_object_ref(user_data),
                  g_object_unref);
}

// -------- Connection telemetry (EventChannel "vpn_plugin_event_channel_query_log") --------

static void send_connection_info(VpnPlugin* self, const std::string& json) {
  if (self->query_log_event_channel == NULL || !self->query_log_listening) {
    if (self->connection_info_ring != nullptr) {
      if (self->connection_info_ring->size() >= kConnectionInfoRingSize) {
        self->connection_info_ring->pop_front();
      }
      self->connection_info_ring->push_back(json);
    }
    return;
  }
  g_autoptr(FlValue) event = fl_value_new_string(json.c_str());
  fl_event_channel_send(self->query_log_event_channel, event, NULL, NULL);
}

static gboolean replay_ring_idle(gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  if (self->connection_info_ring != nullptr && self->query_log_listening &&
      self->query_log_event_channel != NULL) {
    for (const std::string& json : *self->connection_info_ring) {
      g_autoptr(FlValue) event = fl_value_new_string(json.c_str());
      fl_event_channel_send(self->query_log_event_channel, event, NULL, NULL);
    }
  }
  return G_SOURCE_REMOVE;
}

// -------- IVpnManager implementation (Pigeon-generated vtable) --------

static VpnPluginIVpnManagerStartResponse* start(const gchar* config,
                                                gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  std::string error;
  if (!self->engine->Start(config != NULL ? config : "", &error)) {
    return vpn_plugin_i_vpn_manager_start_response_new_error(
        "vpn_start_failed", error.c_str(), NULL);
  }
  return vpn_plugin_i_vpn_manager_start_response_new();
}

static VpnPluginIVpnManagerStopResponse* stop(gpointer user_data) {
  VPN_PLUGIN(user_data)->engine->Stop();
  return vpn_plugin_i_vpn_manager_stop_response_new();
}

static VpnPluginIVpnManagerUpdateConfigurationResponse* update_configuration(
    const gchar* /*config*/,
    gpointer /*user_data*/) {
  // System VPN profile management applies to Apple platforms only.
  return vpn_plugin_i_vpn_manager_update_configuration_response_new();
}

static VpnPluginIVpnManagerGetCurrentStateResponse* get_current_state(gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  const auto state = static_cast<VpnPluginVpnManagerState>(self->engine->GetCurrentState());
  return vpn_plugin_i_vpn_manager_get_current_state_response_new(state);
}

static VpnPluginIVpnManagerExportLogsResponse* export_logs(gpointer /*user_data*/) {
  // TODO: implement log export on Linux: the daemon does not persist logs yet.
  // Once it writes log files (e.g. /var/log/trusttunnel/ or the app support
  // directory), return their paths here so the GUI "Export logs" button can
  // hand the files to the user. The daemon is bundled with the application
  // (TRUSTTUNNEL_CLIENT_DAEMON), so the log directory should live next to the
  // user data, not in the read-only bundle.
  FlValue* paths = fl_value_new_list();
  VpnPluginIVpnManagerExportLogsResponse* response =
      vpn_plugin_i_vpn_manager_export_logs_response_new(paths);
  fl_value_unref(paths);
  return response;
}

static VpnPluginIVpnManagerClearLogsResponse* clear_logs(gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  if (self->transport != nullptr) {
    self->transport->ClearLogs();
  }
  return vpn_plugin_i_vpn_manager_clear_logs_response_new();
}

// -------- IDeepLink implementation (Pigeon-generated vtable) --------

static VpnPluginIDeepLinkDecodeResponse* decode(const gchar* uri, gpointer /*user_data*/) {
  std::string configuration;
  std::string error;
  if (!vpn_plugin::DecodeTrustTunnelDeepLink(uri != NULL ? uri : "", &configuration, &error)) {
    return vpn_plugin_i_deep_link_decode_response_new_error(
        "decode_error", error.c_str(), NULL);
  }

  return vpn_plugin_i_deep_link_decode_response_new(configuration.c_str());
}

// -------- EventChannel stream handlers --------

static FlMethodErrorResponse* state_listen_cb(FlEventChannel* /*channel*/,
                                              FlValue* /*args*/,
                                              gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  self->state_listening = TRUE;
  emit_vpn_state(self);
  return NULL;
}

static FlMethodErrorResponse* state_cancel_cb(FlEventChannel* /*channel*/,
                                              FlValue* /*args*/,
                                              gpointer user_data) {
  VPN_PLUGIN(user_data)->state_listening = FALSE;
  return NULL;
}

static FlMethodErrorResponse* query_log_listen_cb(FlEventChannel* /*channel*/,
                                                  FlValue* /*args*/,
                                                  gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  self->query_log_listening = TRUE;
  // Replay the records buffered before the listener attached.
  g_idle_add_full(G_PRIORITY_DEFAULT, replay_ring_idle, g_object_ref(self),
                  g_object_unref);
  return NULL;
}

static FlMethodErrorResponse* query_log_cancel_cb(FlEventChannel* /*channel*/,
                                                  FlValue* /*args*/,
                                                  gpointer user_data) {
  VPN_PLUGIN(user_data)->query_log_listening = FALSE;
  return NULL;
}

// -------- GObject lifecycle --------

static void vpn_plugin_dispose(GObject* object) {
  VpnPlugin* self = VPN_PLUGIN(object);

  // GObject may invoke dispose more than once; null the pointers out so the
  // second pass is a no-op.
  delete self->engine;
  self->engine = nullptr;
  delete self->transport;
  self->transport = nullptr;
  delete self->connection_info_ring;
  self->connection_info_ring = nullptr;

  if (self->messenger != NULL) {
    vpn_plugin_i_vpn_manager_clear_method_handlers(self->messenger, NULL);
    vpn_plugin_i_deep_link_clear_method_handlers(self->messenger, NULL);
    g_clear_object(&self->messenger);
  }
  g_clear_object(&self->state_event_channel);
  g_clear_object(&self->query_log_event_channel);

  G_OBJECT_CLASS(vpn_plugin_parent_class)->dispose(object);
}

static void vpn_plugin_class_init(VpnPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = vpn_plugin_dispose;
}

static void vpn_plugin_init(VpnPlugin* self) {
  self->transport = new vpn_plugin::TrustTunnelDBusTransport();
  self->engine = new vpn_plugin::LinuxVpnEngine(self->transport, on_engine_state, self);
  self->connection_info_ring = new std::deque<std::string>();
  self->state_listening = FALSE;
  self->query_log_listening = FALSE;

  // Daemon signals are delivered on the GLib main context, so publishing them
  // to the Flutter EventChannels is safe here without extra marshalling.
  self->engine->SetConnectionInfoSink([self](const std::string& json) {
    send_connection_info(self, json);
  });
}

void vpn_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  VpnPlugin* plugin = VPN_PLUGIN(g_object_new(vpn_plugin_get_type(), NULL));
  plugin->messenger = g_object_ref(fl_plugin_registrar_get_messenger(registrar));

  g_autoptr(FlStandardMethodCodec) method_codec = fl_standard_method_codec_new();

  plugin->state_event_channel =
      fl_event_channel_new(plugin->messenger, kStateEventChannelName,
                           FL_METHOD_CODEC(method_codec));
  fl_event_channel_set_stream_handlers(plugin->state_event_channel, state_listen_cb,
                                       state_cancel_cb, g_object_ref(plugin), g_object_unref);

  plugin->query_log_event_channel =
      fl_event_channel_new(plugin->messenger, kQueryLogEventChannelName,
                           FL_METHOD_CODEC(method_codec));
  fl_event_channel_set_stream_handlers(plugin->query_log_event_channel, query_log_listen_cb,
                                       query_log_cancel_cb, g_object_ref(plugin),
                                       g_object_unref);

  // Field order: start, stop, update_configuration, get_current_state,
  // export_logs, clear_logs.
  static const VpnPluginIVpnManagerVTable kVpnVTable = {
      start,
      stop,
      update_configuration,
      get_current_state,
      export_logs,
      clear_logs,
  };
  vpn_plugin_i_vpn_manager_set_method_handlers(plugin->messenger, NULL, &kVpnVTable,
                                               g_object_ref(plugin), g_object_unref);

  static const VpnPluginIDeepLinkVTable kDeepLinkVTable = {
      decode,
  };
  vpn_plugin_i_deep_link_set_method_handlers(plugin->messenger, NULL, &kDeepLinkVTable,
                                             g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
