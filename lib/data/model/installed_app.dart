import 'package:flutter/foundation.dart';

export 'package:vpn_plugin/vpn_plugin.dart' show InstalledApp;

/// {@template ru_app_preset}
/// A known application preset entry recommended for exclusion from the VPN.
/// {@endtemplate}
@immutable
final class RuAppPreset {
  /// Android package name.
  final String packageName;

  /// Human-readable name shown in the UI.
  final String name;

  /// {@macro ru_app_preset}
  const RuAppPreset({
    required this.packageName,
    required this.name,
  });

  @override
  bool operator ==(Object other) => identical(this, other) || (other is RuAppPreset && other.packageName == packageName);

  @override
  int get hashCode => packageName.hashCode;
}
