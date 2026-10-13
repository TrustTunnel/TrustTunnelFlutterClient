#include "include/vpn_plugin/vpn_plugin.h"

#include "platform_api.g.h"

#include <string.h>

#define VPN_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), vpn_plugin_get_type(), VpnPlugin))

static const char kStateEventChannelName[] = "vpn_plugin_event_channel";
static const char kQueryLogEventChannelName[] = "vpn_plugin_event_channel_query_log";

// The stub VPN engine transitions connecting -> connected after this delay.
static const guint kConnectTimeoutMs = 2000;

struct _VpnPlugin {
  GObject parent_instance;

  VpnPluginVpnManagerState state;
  guint connect_timeout_id;

  // EventChannel "vpn_plugin_event_channel": bare VpnManagerState ints.
  // Not part of the Pigeon schema, so it stays hand-written.
  FlEventChannel* state_event_channel;
  gboolean state_listening;

  // EventChannel "vpn_plugin_event_channel_query_log": no events in the stub,
  // handlers are registered so the Dart broadcast stream does not error.
  FlEventChannel* query_log_event_channel;

  FlBinaryMessenger* messenger;
};

G_DEFINE_TYPE(VpnPlugin, vpn_plugin, g_object_get_type())

// -------- VPN state (EventChannel "vpn_plugin_event_channel") --------

static void emit_vpn_state(VpnPlugin* self) {
  if (self->state_event_channel == NULL || !self->state_listening) return;
  g_autoptr(FlValue) event = fl_value_new_int(self->state);
  fl_event_channel_send(self->state_event_channel, event, NULL, NULL);
}

static void set_vpn_state(VpnPlugin* self, VpnPluginVpnManagerState state) {
  self->state = state;
  emit_vpn_state(self);
}

static gboolean on_connect_timeout(gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  self->connect_timeout_id = 0;
  set_vpn_state(self, VPN_PLUGIN_VPN_MANAGER_STATE_CONNECTED);
  return G_SOURCE_REMOVE;
}

// -------- IVpnManager implementation (Pigeon-generated vtable) --------

static VpnPluginIVpnManagerStartResponse* start(const gchar* /*config*/,
                                                gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  if (self->connect_timeout_id != 0) g_source_remove(self->connect_timeout_id);
  set_vpn_state(self, VPN_PLUGIN_VPN_MANAGER_STATE_CONNECTING);
  self->connect_timeout_id = g_timeout_add(kConnectTimeoutMs, on_connect_timeout, self);
  return vpn_plugin_i_vpn_manager_start_response_new();
}

static VpnPluginIVpnManagerStopResponse* stop(gpointer user_data) {
  VpnPlugin* self = VPN_PLUGIN(user_data);
  if (self->connect_timeout_id != 0) {
    g_source_remove(self->connect_timeout_id);
    self->connect_timeout_id = 0;
  }
  set_vpn_state(self, VPN_PLUGIN_VPN_MANAGER_STATE_DISCONNECTED);
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
  return vpn_plugin_i_vpn_manager_get_current_state_response_new(self->state);
}

static VpnPluginIVpnManagerExportLogsResponse* export_logs(gpointer /*user_data*/) {
  // Exported log file paths; none in the stub. The response keeps a reference
  // of its own, so release ours after handing the list over.
  FlValue* paths = fl_value_new_list();
  VpnPluginIVpnManagerExportLogsResponse* response =
      vpn_plugin_i_vpn_manager_export_logs_response_new(paths);
  fl_value_unref(paths);
  return response;
}

static VpnPluginIVpnManagerClearLogsResponse* clear_logs(gpointer /*user_data*/) {
  return vpn_plugin_i_vpn_manager_clear_logs_response_new();
}

// -------- IDeepLink implementation (Pigeon-generated vtable) --------

static gboolean is_base64_char(char c) {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
         c == '+' || c == '/' || c == '=';
}

// Decodes standard and URL-safe base64 into a freshly allocated
// NUL-terminated byte string; returns NULL when nothing could be decoded.
static gchar* base64_decode_string(const gchar* input) {
  if (input == NULL) return NULL;

  const size_t input_len = strlen(input);
  GString* cleaned = g_string_sized_new(input_len + 4);
  for (size_t i = 0; i < input_len; i++) {
    char c = input[i];
    if (c == '-') c = '+';  // URL-safe alphabet
    else if (c == '_') c = '/';
    else if (!is_base64_char(c)) continue;  // skip whitespace/newlines
    g_string_append_c(cleaned, c);
  }
  while (cleaned->len % 4 != 0) g_string_append_c(cleaned, '=');

  gsize decoded_len = 0;
  guchar* decoded = g_base64_decode(cleaned->str, &decoded_len);
  g_string_free(cleaned, TRUE);

  if (decoded_len == 0) {
    g_free(decoded);
    return NULL;
  }
  return (gchar*)g_realloc(decoded, decoded_len + 1);
}

static VpnPluginIDeepLinkDecodeResponse* decode(const gchar* uri, gpointer /*user_data*/) {
  // Best effort: percent-decode first (deep links carry the base64 payload in
  // the URI), fall back to the raw string, then base64-decode the result.
  gchar* unescaped = g_uri_unescape_string(uri != NULL ? uri : "", NULL);
  gchar* decoded = base64_decode_string(unescaped != NULL ? unescaped : uri);
  g_free(unescaped);
  if (decoded == NULL) {
    return vpn_plugin_i_deep_link_decode_response_new_error(
        "decode_error", "Failed to decode deep link URI.", NULL);
  }

  VpnPluginIDeepLinkDecodeResponse* response = vpn_plugin_i_deep_link_decode_response_new(decoded);
  g_free(decoded);
  return response;
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
                                                  gpointer /*user_data*/) {
  return NULL;
}

static FlMethodErrorResponse* query_log_cancel_cb(FlEventChannel* /*channel*/,
                                                  FlValue* /*args*/,
                                                  gpointer /*user_data*/) {
  return NULL;
}

// -------- GObject lifecycle --------

static void vpn_plugin_dispose(GObject* object) {
  VpnPlugin* self = VPN_PLUGIN(object);

  if (self->connect_timeout_id != 0) {
    g_source_remove(self->connect_timeout_id);
    self->connect_timeout_id = 0;
  }
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
  self->state = VPN_PLUGIN_VPN_MANAGER_STATE_DISCONNECTED;
  self->connect_timeout_id = 0;
  self->state_listening = FALSE;
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
