import Cocoa
import FlutterMacOS

public class VpnPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
      let messenger = registrar.messenger
      PlatformApiSetup.setUp(binaryMessenger: messenger, api: PlatformApiImpl())
  }
}

public class PlatformApiImpl: NSObject, PlatformApi {
    func getPlatformType(request: GetPlatformTypeRequest) throws -> GetPlatformTypeResponse {
        let response = GetPlatformTypeResponse(platformType: "MacOS")
        return response
    }
}
