import Flutter
import UIKit

public class VpnPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
      let messenger = registrar.messenger()
      let api = PlatformApiImpl()
      PlatformApiSetup.setUp(binaryMessenger: messenger, api: api)
      let eventChannel = FlutterEventChannel(name: "vpn_plugin_event_channel",
                                             binaryMessenger: messenger)
      eventChannel.setStreamHandler(api)
  }
}

public class PlatformApiImpl: NSObject, PlatformApi, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            events(0)
            return nil
        }
        
        public func onCancel(withArguments arguments: Any?) -> FlutterError? {
            return nil
        }
        
       
        
        func getAllServers() throws -> [Server] {
            return [
                Server(id: 0, name: "name", ipAddress: "ipAddress", domain: "domain", login: "login", password: "password", vpnProtocol: VpnProtocol.http2, routingProfileId: 0, dnsServers: ["111", "222"])]
        }
        
        func getServerById(id: Int64) throws -> Server {
            return Server(id: 0, name: "name", ipAddress: "ipAddress", domain: "domain", login: "login", password: "password", vpnProtocol: VpnProtocol.http2, routingProfileId: 0, dnsServers: ["111", "222"])
        }
        
        func addServer(request: AddServerRequest) throws -> Server {
            return Server(id: 0, name: "name", ipAddress: "ipAddress", domain: "domain", login: "login", password: "password", vpnProtocol: VpnProtocol.http2, routingProfileId: 0, dnsServers: ["111", "222"])
        }
        
        func updateServer(request: UpdateServerRequest) throws -> Server {
            return Server(id: 0, name: "name", ipAddress: "ipAddress", domain: "domain", login: "login", password: "password", vpnProtocol: VpnProtocol.http2, routingProfileId: 0, dnsServers: ["111", "222"])
        }
        
        func removeServer(id: Int64) throws {
            
        }
        
        func getSelectedServerId() throws -> Int64? {
            return 0
        }
        
        func setSelectedServerId(id: Int64) throws {
            
        }
        
        func getAllRoutingProfiles() throws -> [RoutingProfile] {
            return [RoutingProfile(id: 0, name: "name", defaultMode: RoutingMode.bypass, bypassRules: [], vpnRules: [])]
        }
        
        func getRoutingProfileById(id: Int64) throws -> RoutingProfile {
            return RoutingProfile(id: 0, name: "name", defaultMode: RoutingMode.bypass, bypassRules: [], vpnRules: [])
        }
        
        func addRoutingProfile(request: AddRoutingProfileRequest) throws -> RoutingProfile {
            return RoutingProfile(id: 0, name: "name", defaultMode: RoutingMode.bypass, bypassRules: [], vpnRules: [])
        }
        
        func updateRoutingProfile(request: UpdateRoutingProfileRequest) throws -> RoutingProfile {
            return RoutingProfile(id: 0, name: "name", defaultMode: RoutingMode.bypass, bypassRules: [], vpnRules: [])
        }
        
        func setRoutingProfileName(name: String) throws {
            
        }
        
        func removeRoutingProfile(id: Int64) throws {
            
        }
        
        func getAllRequests() throws -> [VpnRequest] {
            return []
        }
        
        func setExcludedRoutes(routes: String) throws {
            
        }
        
        func getExcludedRoutes() throws -> String {
            return ""
        }
        
        func start() throws {
            
        }
        
        func stop() throws {
            
        }
        
        func getCurrentState() throws -> VpnManagerState {
            return VpnManagerState.connected
        }
        
        func errorStub(error: PlatformErrorResponse) throws {
            
        }

}
