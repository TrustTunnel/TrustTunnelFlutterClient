#pragma once

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

/**
 * Register the VPN plugin with the Flutter engine.
 * @param registrar The desktop plugin registrar reference.
 */
FLUTTER_PLUGIN_EXPORT void VpnPluginCApiRegisterWithRegistrar(
        FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
} // extern "C"
#endif
