import 'package:flutter/foundation.dart';

/// {@template tun}
/// TUN configuration .
///
/// This model provides:
/// - routes to include in tunneling ([includedRoutes]),
/// - routes to exclude ([excludedRoutes]),
/// - and the interface MTU ([mtuSize]).
///
/// Values are forwarded to the backend as provided. Only [mtuSize] has a basic
/// invariant enforced locally.
/// {@endtemplate}
final class Tun {
  /// {@template tun_included_routes}
  /// CIDR routes that should be routed through the virtual interface.
  ///
  /// Defaults include IPv4 default route and the common IPv6 global unicast
  /// range.
  /// {@endtemplate}
  final List<String> includedRoutes;

  /// {@template tun_excluded_routes}
  /// CIDR routes that should be excluded from tunneling.
  /// {@endtemplate}
  final List<String> excludedRoutes;

  /// {@template tun_mtu_size}
  /// MTU size for the virtual interface.
  ///
  /// Must be greater than zero. The constructor asserts this invariant.
  /// {@endtemplate}
  final int mtuSize;

  /// {@macro tun}
  Tun({
    this.includedRoutes = const [
      '0.0.0.0/0',
      '2000::/3',
    ],
    this.excludedRoutes = const [],
    this.mtuSize = 1280,
  }) : assert(mtuSize > 0, 'mtuSize must be greater than 0');

  @override
  String toString() => 'Tun(includedRoutes: $includedRoutes, excludedRoutes: $excludedRoutes, mtuSize: $mtuSize)';

  @override
  bool operator ==(covariant Tun other) {
    if (identical(this, other)) return true;

    return listEquals(other.includedRoutes, includedRoutes) &&
        listEquals(other.excludedRoutes, excludedRoutes) &&
        other.mtuSize == mtuSize;
  }

  @override
  int get hashCode => Object.hashAll([
    includedRoutes.hashCode,
    excludedRoutes.hashCode,
    mtuSize.hashCode,
  ]);
}
