#include "include/tray_manager/tray_manager_plugin_c_api.h"

#include "tray_manager_plugin.h"

void TrayManagerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  tray_manager::TrayManagerPlugin::RegisterWithRegistrar(registrar);
}
