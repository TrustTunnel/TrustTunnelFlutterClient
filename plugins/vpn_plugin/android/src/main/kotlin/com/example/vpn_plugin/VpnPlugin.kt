package com.example.vpn_plugin


import io.flutter.embedding.engine.plugins.FlutterPlugin

/** VpnPlugin */
class VpnPlugin: FlutterPlugin{

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    PlatformApi.setUp(flutterPluginBinding.binaryMessenger, PlatformApiImpl())
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}

internal class PlatformApiImpl : PlatformApi {
  override fun getPlatformType(request: GetPlatformTypeRequest): GetPlatformTypeResponse {
    return GetPlatformTypeResponse(platformType = "Android")
  }
}