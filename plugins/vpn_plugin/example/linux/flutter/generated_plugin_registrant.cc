//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <vpn_plugin/vpn_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) vpn_plugin_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "VpnPlugin");
  vpn_plugin_register_with_registrar(vpn_plugin_registrar);
}
