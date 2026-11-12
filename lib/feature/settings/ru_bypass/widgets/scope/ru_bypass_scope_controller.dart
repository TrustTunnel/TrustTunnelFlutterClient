import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';

/// {@template ru_bypass_scope_controller}
/// Public contract of the Runet bypass scope.
/// {@endtemplate}
abstract class RuBypassScopeController implements Listenable {
  /// Whether Runet bypass is enabled.
  abstract final bool enabled;

  /// Timestamp of the last successful CIDR list update (or `null`).
  abstract final DateTime? lastUpdateDate;

  /// Number of stored CIDR entries.
  abstract final int cidrCount;

  /// Stored CIDR entries merged into the effective VPN exclusions.
  abstract final List<String> cidrList;

  /// Whether an operation is in progress.
  abstract final bool loading;

  abstract final PresentationException? error;

  abstract final void Function() fetchRuBypass;

  /// Toggles Runet bypass (persisted immediately).
  abstract final void Function(bool enabled) changeEnabled;

  /// Re-downloads the RU CIDR list (persisted immediately).
  abstract final void Function(void Function(int cidrCount) onSuccess) updateLists;
}
