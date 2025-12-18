import 'dart:async';

import 'package:trusttunnel/common/extensions/model_extensions.dart';
import 'package:trusttunnel/common/utils/upstream_protocol_encoder.dart';
import 'package:trusttunnel/common/utils/validation_utils.dart';
import 'package:trusttunnel/common/utils/vpn_mode_encoder.dart';
import 'package:trusttunnel/data/datasources/vpn_datasource.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/vpn/domain/services/vpn_log_converter.dart';
import 'package:vpn_plugin/models/configuration.dart';
import 'package:vpn_plugin/models/endpoint.dart';
import 'package:vpn_plugin/models/query_log_row.dart';
import 'package:vpn_plugin/models/socks.dart';
import 'package:vpn_plugin/models/tun.dart';
import 'package:vpn_plugin/platform_api.g.dart' as p;
import 'package:vpn_plugin/vpn_plugin.dart';

/// {@template vpn_data_source_impl}
/// Platform-backed implementation of [VpnDataSource].
///
/// This implementation adapts the generated plugin API ([VpnPlugin]) to the
/// domain-level abstractions used by the app. Its responsibilities include:
/// - converting platform enums and models into domain equivalents,
/// - constructing a platform [Configuration] from domain models,
/// - exposing platform streams as domain streams.
///
/// This class does not cache state or retry operations; it is a thin translation
/// layer between Dart domain code and the platform channel.
/// {@endtemplate}
class VpnDataSourceImpl implements VpnDataSource {
  final VpnPlugin _platformApi;

  /// {@macro vpn_data_source_impl}
  VpnDataSourceImpl({
    required VpnPlugin vpnPlugin,
  }) : _platformApi = vpnPlugin;

  /// {@macro vpn_data_source_state_stream}
  ///
  /// Platform states are converted to [VpnState]. When the underlying platform
  /// state stream completes, the VPN is explicitly stopped and a final
  /// [VpnState.disconnected] value is emitted before closing the stream.
  @override
  Stream<VpnState> get vpnState => _platformApi.states.transform(
    StreamTransformer<p.VpnManagerState, VpnState>.fromHandlers(
      handleData: (data, sink) => sink.add(
        VpnStateFromApi.parse(data),
      ),
      handleDone: (sink) async {
        await _platformApi.stop();
        sink.add(VpnState.disconnected);
        sink.close();
      },
    ),
  );

  /// {@macro vpn_data_source_logs_stream}
  ///
  /// Platform log rows are converted into domain [VpnLog] entries.
  @override
  Stream<VpnLog> get vpnLogs => _platformApi.queryLog.transform(
    StreamTransformer<QueryLogRow, VpnLog>.fromHandlers(
      handleData: (data, sink) => sink.add(
        VpnLogConverter().convert(data),
      ),
      handleDone: (sink) {
        sink.close();
      },
    ),
  );

  /// {@macro vpn_data_source_start}
  ///
  /// This implementation:
  /// 1) derives exclusions based on the routing profile,
  /// 2) constructs a platform [Endpoint] and [Configuration],
  /// 3) invokes the platform `start` command.
  @override
  Future<void> start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) {
    final exclusions = _getExclusionsByMode(routingProfile);

    final endPoint = Endpoint(
      hostName: server.domain,
      hasIpv6: false,
      username: server.username,
      password: server.password,
      addresses: [
        server.ipAddress,
      ],
      exclusions: exclusions,
      dnsUpStreams: server.dnsServers,
      upStreamProtocol: UpStreamProtocolEncoder().convert(
        server.vpnProtocol,
      ),
    );

    return _platformApi.start(
      configuration: Configuration(
        vpnMode: VpnModeEncoder().convert(
          routingProfile.defaultMode,
        ),
        endpoint: endPoint,
        tun: Tun(
          excludedRoutes: excludedRoutes,
        ),
        socks: Socks(),
      ),
    );
  }

  /// {@macro vpn_data_source_stop}
  @override
  Future<void> stop() => _platformApi.stop();

  /// {@macro vpn_data_source_request_state}
  ///
  /// The platform state is converted into a domain [VpnState].
  @override
  Future<VpnState> requestState() async {
    final state = await _platformApi.getCurrentState();

    return VpnStateFromApi.parse(state);
  }

  /// Computes the effective exclusion list based on routing mode.
  ///
  /// Domains are normalized to include wildcard variants when appropriate.
  List<String> _getExclusionsByMode(RoutingProfile profile) {
    final List<String> exclusions;

    switch (profile.defaultMode) {
      case RoutingMode.bypass:
        exclusions = profile.vpnRules;
      case RoutingMode.vpn:
        exclusions = profile.bypassRules;
    }

    const wildCard = '*.';
    final Set<String> parsedDomains = {};
    final Set<String> parsedAddresses = {};

    for (final exclusion in exclusions) {
      final domainValue = ValidationUtils.tryParseDomain(exclusion);

      if (domainValue == null) {
        parsedAddresses.add(exclusion);
        continue;
      }

      parsedDomains.add(domainValue);
      if (!domainValue.startsWith(wildCard)) {
        parsedDomains.add('$wildCard$domainValue');
      }
    }

    return {
      ...parsedAddresses,
      ...parsedDomains,
    }.toList();
  }
}
