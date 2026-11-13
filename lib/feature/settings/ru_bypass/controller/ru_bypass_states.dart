import 'package:trusttunnel/common/error/model/presentation_exception.dart';

/// {@template ru_bypass_state}
/// State representation for the Runet bypass feature.
/// {@endtemplate}
sealed class RuBypassState {
  /// Whether Runet bypass is enabled.
  final bool enabled;

  /// Timestamp of the last successful CIDR list update (or `null`).
  final DateTime? lastUpdateDate;

  /// Number of stored CIDR entries.
  final int cidrCount;

  const RuBypassState._({
    required this.enabled,
    required this.lastUpdateDate,
    required this.cidrCount,
  });

  const factory RuBypassState.initial() = _InitialRuBypassState;

  /// Initial / idle state
  const factory RuBypassState.idle({
    required bool enabled,
    required DateTime? lastUpdateDate,
    required int cidrCount,
  }) = _IdleRuBypassState;

  /// Loading state (initial fetch or list update).
  const factory RuBypassState.loading({
    required bool enabled,
    required DateTime? lastUpdateDate,
    required int cidrCount,
  }) = _LoadingRuBypassState;

  /// Error state
  const factory RuBypassState.exception({
    required bool enabled,
    required DateTime? lastUpdateDate,
    required int cidrCount,
    required PresentationException exception,
  }) = _ErrorRuBypassState;

  PresentationException? get error => this is _ErrorRuBypassState ? (this as _ErrorRuBypassState).exception : null;

  bool get loading => this is _LoadingRuBypassState;

  @override
  String toString() =>
      'RuBypassState(type: $runtimeType, enabled: $enabled, lastUpdateDate: $lastUpdateDate, cidrCount: $cidrCount)';
}

final class _IdleRuBypassState extends RuBypassState {
  const _IdleRuBypassState({
    required super.enabled,
    required super.lastUpdateDate,
    required super.cidrCount,
  }) : super._();
}

final class _InitialRuBypassState extends _IdleRuBypassState {
  const _InitialRuBypassState()
    : super(
        enabled: false,
        lastUpdateDate: null,
        cidrCount: 0,
      );
}

final class _LoadingRuBypassState extends RuBypassState {
  const _LoadingRuBypassState({
    required super.enabled,
    required super.lastUpdateDate,
    required super.cidrCount,
  }) : super._();
}

final class _ErrorRuBypassState extends RuBypassState {
  final PresentationException exception;

  const _ErrorRuBypassState({
    required super.enabled,
    required super.lastUpdateDate,
    required super.cidrCount,
    required this.exception,
  }) : super._();
}
