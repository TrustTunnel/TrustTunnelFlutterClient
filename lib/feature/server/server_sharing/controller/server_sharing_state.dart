import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class ServerSharingState {
  const ServerSharingState();

  const factory ServerSharingState.initial() = _ServerSharingInitialState;

  const factory ServerSharingState.idle() = _ServerSharingIdleState;

  const factory ServerSharingState.loading() = _ServerSharingLoadingState;

  const factory ServerSharingState.error(
    PresentationException error,
  ) = _ServerSharingErrorState;

  PresentationException? get error => switch (this) {
    _ServerSharingErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is _ServerSharingLoadingState;

  @override
  String toString() => 'ServerSharingState(type: $runtimeType, loading: $loading)';
}

final class _ServerSharingInitialState extends _ServerSharingIdleState {
  const _ServerSharingInitialState() : super();
}

final class _ServerSharingIdleState extends ServerSharingState {
  const _ServerSharingIdleState();
}

final class _ServerSharingLoadingState extends ServerSharingState {
  const _ServerSharingLoadingState();
}

final class _ServerSharingErrorState extends ServerSharingState {
  @override
  final PresentationException error;

  const _ServerSharingErrorState(
    this.error,
  );
}
