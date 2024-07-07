#include "include/vpn_plugin/vpn_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "vpn_plugin.h"

void VpnPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  vpn_plugin::VpnPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
