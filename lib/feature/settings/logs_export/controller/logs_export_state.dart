import 'package:trusttunnel/common/error/model/presentation_error.dart';

sealed class LogsExportState {
  const LogsExportState();

  const factory LogsExportState.idle() = LogsExportIdleState;

  const factory LogsExportState.loading() = LogsExportLoadingState;

  const factory LogsExportState.error(PresentationError error) = LogsExportErrorState;

  bool get processing => this is LogsExportLoadingState;

  PresentationError? get error => switch (this) {
    LogsExportErrorState(:final error) => error,
    _ => null,
  };

  @override
  String toString() {
    String phaseName;
    if (processing) {
      phaseName = 'loading';
    } else if (error != null) {
      phaseName = 'error';
    } else {
      phaseName = 'idle';
    }

    return 'LogsExportState(phase: $phaseName, error: ${error?.runtimeType})';
  }
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
