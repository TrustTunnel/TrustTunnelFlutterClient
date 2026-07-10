import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class LogsManagerState {
  const LogsManagerState();

  const factory LogsManagerState.initial() = _LogsManagerInitialState;

  const factory LogsManagerState.idle() = _LogsManagerIdleState;

  const factory LogsManagerState.loading() = _LogsManagerLoadingState;

  const factory LogsManagerState.error(
    PresentationException error,
  ) = _LogsManagerErrorState;

  PresentationException? get error => switch (this) {
    _LogsManagerErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is _LogsManagerLoadingState;

  @override
  String toString() => 'LogsManagerState(type: $runtimeType, loading: $loading)';
}

final class _LogsManagerInitialState extends _LogsManagerIdleState {
  const _LogsManagerInitialState() : super();
}

final class _LogsManagerIdleState extends LogsManagerState {
  const _LogsManagerIdleState();
}

final class _LogsManagerLoadingState extends LogsManagerState {
  const _LogsManagerLoadingState();
}

final class _LogsManagerErrorState extends LogsManagerState {
  @override
  final PresentationException error;

  const _LogsManagerErrorState(
    this.error,
  );
}
