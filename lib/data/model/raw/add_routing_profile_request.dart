import 'package:trusttunnel/data/model/routing_mode.dart';

/// {@template add_routing_profile_request}
/// Input payload for creating a routing profile.
///
/// This is a lightweight request DTO represented as a Dart record.
/// It contains profile metadata and both rule sets.
///
/// The rule strings are stored as provided; validation and normalization are
/// expected to happen at higher layers if needed.
/// {@endtemplate}
typedef AddRoutingProfileRequest = ({
  /// User-visible profile name.
  String name,

  /// Default routing mode used when interpreting the rule sets.
  RoutingMode defaultMode,

  /// Rule strings associated with bypass handling.
  List<String> bypassRules,

  /// Rule strings associated with VPN handling.
  List<String> vpnRules,
});
