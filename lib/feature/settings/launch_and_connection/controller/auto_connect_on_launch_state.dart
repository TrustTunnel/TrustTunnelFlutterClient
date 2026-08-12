import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class AutoConnectOnLaunchState {
  final bool enabled;
  final String? lastServerId;
  final bool connectOnLaunchHandled;

  const AutoConnectOnLaunchState({
    required this.enabled,
    required this.lastServerId,
    required this.connectOnLaunchHandled,
  });

  const factory AutoConnectOnLaunchState.initial() = _AutoConnectOnLaunchInitialState;

  const factory AutoConnectOnLaunchState.idle({
    required bool enabled,
    required String? lastServerId,
    required bool connectOnLaunchHandled,
  }) = _AutoConnectOnLaunchIdleState;

  const factory AutoConnectOnLaunchState.loading({
    required bool enabled,
    required String? lastServerId,
    required bool connectOnLaunchHandled,
  }) = _AutoConnectOnLaunchLoadingState;

  const factory AutoConnectOnLaunchState.error({
    required bool enabled,
    required String? lastServerId,
    required bool connectOnLaunchHandled,
    required PresentationException error,
  }) = _AutoConnectOnLaunchErrorState;

  PresentationException? get error => switch (this) {
    _AutoConnectOnLaunchErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is _AutoConnectOnLaunchLoadingState;

  bool get initial => this is _AutoConnectOnLaunchInitialState;

  @override
  int get hashCode => Object.hash(
    enabled,
    lastServerId,
    connectOnLaunchHandled,
    error,
    loading,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoConnectOnLaunchState &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          lastServerId == other.lastServerId &&
          connectOnLaunchHandled == other.connectOnLaunchHandled &&
          error == other.error &&
          loading == other.loading;

  @override
  String toString() =>
      'AutoConnectOnLaunchState(type: $runtimeType, enabled: $enabled, lastServerId: $lastServerId, '
      'connectOnLaunchHandled: $connectOnLaunchHandled, loading: $loading)';
}

final class _AutoConnectOnLaunchInitialState extends _AutoConnectOnLaunchIdleState {
  const _AutoConnectOnLaunchInitialState()
    : super(
        enabled: false,
        lastServerId: null,
        connectOnLaunchHandled: false,
      );
}

final class _AutoConnectOnLaunchIdleState extends AutoConnectOnLaunchState {
  const _AutoConnectOnLaunchIdleState({
    required super.enabled,
    required super.lastServerId,
    required super.connectOnLaunchHandled,
  });
}

final class _AutoConnectOnLaunchLoadingState extends AutoConnectOnLaunchState {
  const _AutoConnectOnLaunchLoadingState({
    required super.enabled,
    required super.lastServerId,
    required super.connectOnLaunchHandled,
  });
}

final class _AutoConnectOnLaunchErrorState extends AutoConnectOnLaunchState {
  @override
  final PresentationException error;

  const _AutoConnectOnLaunchErrorState({
    required super.enabled,
    required super.lastServerId,
    required super.connectOnLaunchHandled,
    required this.error,
  });
}
