import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class LogsManagerState {
  const LogsManagerState();

  const factory LogsManagerState.initial() = LogsManagerInitialState;

  const factory LogsManagerState.idle() = LogsManagerIdleState;

  const factory LogsManagerState.loading() = LogsManagerLoadingState;

  const factory LogsManagerState.error(
    PresentationException error,
  ) = LogsManagerErrorState;

  PresentationException? get error => switch (this) {
    LogsManagerErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is LogsManagerLoadingState;

  @override
  String toString() => 'LogsManagerState(type: $runtimeType, loading: $loading)';
}

final class LogsManagerInitialState extends LogsManagerIdleState {
  const LogsManagerInitialState() : super();
}

final class LogsManagerIdleState extends LogsManagerState {
  const LogsManagerIdleState();
}

final class LogsManagerLoadingState extends LogsManagerState {
  const LogsManagerLoadingState();
}

final class LogsManagerErrorState extends LogsManagerState {
  @override
  final PresentationException error;

  const LogsManagerErrorState(
    this.error,
  );
}
