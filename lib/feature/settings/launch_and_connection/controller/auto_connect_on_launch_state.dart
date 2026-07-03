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

  const factory AutoConnectOnLaunchState.initial() = AutoConnectOnLaunchInitialState;

  const factory AutoConnectOnLaunchState.idle({
    required bool enabled,
    required String? lastServerId,
    required bool connectOnLaunchHandled,
  }) = AutoConnectOnLaunchIdleState;

  const factory AutoConnectOnLaunchState.loading({
    required bool enabled,
    required String? lastServerId,
    required bool connectOnLaunchHandled,
  }) = AutoConnectOnLaunchLoadingState;

  const factory AutoConnectOnLaunchState.error({
    required bool enabled,
    required String? lastServerId,
    required bool connectOnLaunchHandled,
    required PresentationException error,
  }) = AutoConnectOnLaunchErrorState;

  PresentationException? get error => switch (this) {
    AutoConnectOnLaunchErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is AutoConnectOnLaunchLoadingState;

  bool get initial => this is AutoConnectOnLaunchInitialState;

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

final class AutoConnectOnLaunchInitialState extends AutoConnectOnLaunchIdleState {
  const AutoConnectOnLaunchInitialState()
    : super(
        enabled: false,
        lastServerId: null,
        connectOnLaunchHandled: false,
      );
}

final class AutoConnectOnLaunchIdleState extends AutoConnectOnLaunchState {
  const AutoConnectOnLaunchIdleState({
    required super.enabled,
    required super.lastServerId,
    required super.connectOnLaunchHandled,
  });
}

final class AutoConnectOnLaunchLoadingState extends AutoConnectOnLaunchState {
  const AutoConnectOnLaunchLoadingState({
    required super.enabled,
    required super.lastServerId,
    required super.connectOnLaunchHandled,
  });
}

final class AutoConnectOnLaunchErrorState extends AutoConnectOnLaunchState {
  @override
  final PresentationException error;

  const AutoConnectOnLaunchErrorState({
    required super.enabled,
    required super.lastServerId,
    required super.connectOnLaunchHandled,
    required this.error,
  });
}
