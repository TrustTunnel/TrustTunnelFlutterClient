import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';

/// {@template routing_profile}
/// A named set of routing rules and a default routing mode.
///
/// A routing profile controls how destinations are classified into:
/// - "bypass" rules ([bypassRules]) — destinations that should be handled directly,
/// - "vpn" rules ([vpnRules]) — destinations that should be handled via VPN,
/// depending on [defaultMode] and how higher layers interpret it.
///
/// The rule strings are stored as provided (typically domains, IPs, or CIDR
/// ranges). Validation and normalization, if needed, are expected to happen
/// in upper layers (e.g. when building platform configuration).
///
/// Instances are immutable and use value-based equality.
/// {@endtemplate}
@immutable
class RoutingProfile {
  /// Database identifier of the profile.
  final int id;

  /// User-visible profile name.
  final String name;

  /// Default routing mode used when interpreting the rule sets.
  final RoutingMode defaultMode;

  /// Destinations/rules associated with "bypass" handling.
  ///
  /// The list is expected to be treated as immutable by callers.
  final List<String> bypassRules;

  /// Destinations/rules associated with "VPN" handling.
  ///
  /// The list is expected to be treated as immutable by callers.
  final List<String> vpnRules;

  /// {@macro routing_profile}
  const RoutingProfile({
    required this.id,
    required this.name,
    required this.defaultMode,
    required this.bypassRules,
    required this.vpnRules,
  });

  @override
  int get hashCode => Object.hash(
    id,
    name,
    defaultMode,
    Object.hashAll(bypassRules),
    Object.hashAll(vpnRules),
  );

  @override
  String toString() =>
      'RoutingProfile('
      'id: $id, '
      'name: $name, '
      'defaultMode: $defaultMode, '
      'bypassRules: $bypassRules, '
      'vpnRules: $vpnRules'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RoutingProfile &&
        other.id == id &&
        other.name == name &&
        other.defaultMode == defaultMode &&
        listEquals(other.bypassRules, bypassRules) &&
        listEquals(other.vpnRules, vpnRules);
  }

  /// Creates a copy of this routing profile with the given fields replaced.
  ///
  /// Fields that are not provided retain their original values.
  RoutingProfile copyWith({
    int? id,
    String? name,
    RoutingMode? defaultMode,
    List<String>? bypassRules,
    List<String>? vpnRules,
  }) => RoutingProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    defaultMode: defaultMode ?? this.defaultMode,
    bypassRules: bypassRules ?? this.bypassRules,
    vpnRules: vpnRules ?? this.vpnRules,
  );
}
