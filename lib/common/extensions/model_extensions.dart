import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:vpn_plugin/platform_api.g.dart' as api;

extension VpnStateFromApi on api.VpnManagerState {
  static VpnState parse(api.VpnManagerState state) => switch (state) {
    api.VpnManagerState.connected => VpnState.connected,
    api.VpnManagerState.connecting => VpnState.connecting,
    api.VpnManagerState.disconnected => VpnState.disconnected,
    api.VpnManagerState.waitingForRecovery => VpnState.waitingForRecovery,
    api.VpnManagerState.recovering => VpnState.recovering,
    api.VpnManagerState.waitingForNetwork => VpnState.waitingForNetwork,
  };
}
