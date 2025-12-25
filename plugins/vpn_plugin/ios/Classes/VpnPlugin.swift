import Flutter
import TrustTunnelClient

public class VpnPlugin: NSObject, FlutterPlugin {
    private static var vpnApi: IVpnManagerImpl?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()

        // TODO: Made separated plugin initialization
        // Konstantin Gorynin <k.gorynin@adguard.com>, 25 August 2025
        // Setup all platform managers
        let vpnImpl = IVpnManagerImpl(bundleIdentifier: "com.adguard.TrustTunnel.Extension",
                                              appGroup: "group.com.adguard.TrustTunnel")
        IVpnManagerSetup.setUp(binaryMessenger: messenger, api: vpnImpl)

        let events = FlutterEventChannel(
            name: "vpn_plugin_event_channel", binaryMessenger: messenger)
        events.setStreamHandler(vpnImpl)

        let events_querylog = FlutterEventChannel(
            name: "vpn_plugin_event_channel_query_log", binaryMessenger: messenger)
        events_querylog.setStreamHandler(vpnImpl.queryLogHandler)

        self.vpnApi = vpnImpl
    }
}

final class IVpnManagerImpl: NSObject, IVpnManager, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var vpnManager: VpnManager?
    var queryLogHandler = QueryLogStreamHandler()
    
    init(bundleIdentifier: String, appGroup: String) {
        super.init()
        self.vpnManager = VpnManager(bundleIdentifier: bundleIdentifier, appGroup: appGroup, stateChangeCallback: { [weak self] newState in
            self?.state = VpnManagerState(rawValue: newState)!
        },
        connectionInfoCallback: { [weak self] info in
            DispatchQueue.main.async {
                self?.queryLogHandler.emitQueryLog(info)
            }
        })
    }

    private var state: VpnManagerState = .disconnected {
        didSet {
            DispatchQueue.main.async {
                self.emitState(self.state)
            }
        }
    }

    // MARK: - IVpnManager (Pigeon HostApi)

    func start(serverName: String, config: String) throws {
        vpnManager?.start(serverName: serverName, config: config)
    }

    func stop() throws {
        vpnManager?.stop()
    }

    func getCurrentState() throws -> VpnManagerState {
        return state
    }

    // MARK: - FlutterStreamHandler (EventChannel)

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events
        emitState(state)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    private func emitState(_ s: VpnManagerState) {
        eventSink?(s.rawValue)
    }
}

final class QueryLogStreamHandler : NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var queue: [String] = []

    override init() {
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        self.eventSink = events
        for log in queue {
            self.eventSink!(log)
        }
        queue = []
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func emitQueryLog(_ s: String) {
        if self.eventSink == nil {
            queue.append(s)
        } else {
            self.eventSink!(s)
        }
    }
}
