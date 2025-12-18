import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';

/// {@template routing_details_data}
/// Editable representation of routing profile details.
///
/// `RoutingDetailsData` is intended for **UI editing flows** where a user
/// configures routing behavior (for example, creating or editing a routing
/// profile).
///
/// Validation and normalization of rule strings (domains, IPs, CIDR ranges)
/// are expected to be handled by higher layers before persistence or usage
/// in platform configuration.
///
/// ## Field semantics
/// - [defaultMode] defines the primary routing behavior.
/// - [bypassRules] contains destinations that should be routed directly.
/// - [vpnRules] contains destinations that should be routed through the VPN.
///
/// Instances are immutable and use value-based equality.
/// {@endtemplate}
@immutable
class RoutingDetailsData {
  /// Default routing mode applied when interpreting rule sets.
  ///
  /// Defaults to [RoutingMode.vpn].
  final RoutingMode defaultMode;

  /// Destinations that should be routed directly (bypassing the VPN).
  ///
  /// Stored as entered by the user; not guaranteed to be valid.
  final List<String> bypassRules;

  /// Destinations that should be routed through the VPN.
  ///
  /// Stored as entered by the user; not guaranteed to be valid.
  final List<String> vpnRules;

  /// {@macro routing_details_data}
  const RoutingDetailsData({
    this.defaultMode = RoutingMode.vpn,
    this.bypassRules = const <String>[],
    this.vpnRules = const <String>[],
  });

  @override
  int get hashCode => Object.hash(
    defaultMode,
    Object.hashAll(bypassRules),
    Object.hashAll(vpnRules),
  );

  @override
  String toString() =>
      'RoutingDetailsData('
      'defaultMode: $defaultMode, '
      'bypassRules: $bypassRules, '
      'vpnRules: $vpnRules'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RoutingDetailsData &&
        other.defaultMode == defaultMode &&
        listEquals(other.bypassRules, bypassRules) &&
        listEquals(other.vpnRules, vpnRules);
  }

  RoutingDetailsData copyWith({
    RoutingMode? defaultMode,
    List<String>? bypassRules,
    List<String>? vpnRules,
  }) => RoutingDetailsData(
    defaultMode: defaultMode ?? this.defaultMode,
    bypassRules: bypassRules ?? this.bypassRules,
    vpnRules: vpnRules ?? this.vpnRules,
  );
}
