import 'package:flutter/foundation.dart';

/// {@template ru_bypass_update_result}
/// Result of a Runet bypass list update.
/// {@endtemplate}
@immutable
final class RuBypassUpdateResult {
  /// Number of CIDR entries stored after the update.
  final int cidrCount;

  /// When the update completed.
  final DateTime updatedAt;

  /// {@macro ru_bypass_update_result}
  const RuBypassUpdateResult({
    required this.cidrCount,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuBypassUpdateResult && other.cidrCount == cidrCount && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(cidrCount, updatedAt);

  @override
  String toString() => 'RuBypassUpdateResult(cidrCount: $cidrCount, updatedAt: $updatedAt)';
}
