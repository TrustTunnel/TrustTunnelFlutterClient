import 'package:trusttunnel/common/error/model/presentation_error.dart';

sealed class LogsExportState {
  const LogsExportState();

  const factory LogsExportState.initial() = LogsExportIdleState;

  const factory LogsExportState.idle() = LogsExportIdleState;

  const factory LogsExportState.loading() = LogsExportLoadingState;

  const factory LogsExportState.error(PresentationError error) = LogsExportErrorState;

  bool get processing => this is LogsExportLoadingState;

  PresentationError? get error => switch (this) {
    LogsExportErrorState(:final error) => error,
    _ => null,
  };

  @override
  String toString() => 'LogsExportState(type: $runtimeType, processing: $processing)';
}

final class LogsExportIdleState extends LogsExportState {
  const LogsExportIdleState();
}

final class LogsExportLoadingState extends LogsExportState {
  const LogsExportLoadingState();
}

final class LogsExportErrorState extends LogsExportState {
  @override
  final PresentationError error;

  const LogsExportErrorState(this.error);
}
