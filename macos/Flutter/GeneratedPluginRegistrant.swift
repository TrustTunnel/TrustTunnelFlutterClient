//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import app_links
import file_picker_darwin
import package_info_plus
import shared_preferences_foundation
import tray_manager
import url_launcher_macos
import vpn_plugin
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AppLinksMacosPlugin.register(with: registry.registrar(forPlugin: "AppLinksMacosPlugin"))
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  TrayManagerMacosPlugin.register(with: registry.registrar(forPlugin: "TrayManagerMacosPlugin"))
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
  VpnPlugin.register(with: registry.registrar(forPlugin: "VpnPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
