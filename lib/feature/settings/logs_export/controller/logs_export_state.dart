import 'dart:io';

import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class LogsExportState {
  const LogsExportState();

  const factory LogsExportState.initial() = LogsExportIdleState;

  const factory LogsExportState.idle({File? archive}) = LogsExportIdleState;

  const factory LogsExportState.loading() = LogsExportLoadingState;

  const factory LogsExportState.error(PresentationException error) = LogsExportErrorState;

  PresentationException? get error => switch (this) {
    LogsExportErrorState(:final error) => error,
    _ => null,
  };

  File? get archive => switch (this) {
    LogsExportIdleState(:final archive) => archive,
    _ => null,
  };

  @override
  String toString() =>
      'LogsExportState(type: $runtimeType, processing: ${this is LogsExportLoadingState}, hasArchive: ${archive != null})';
}

final class LogsExportIdleState extends LogsExportState {
  @override
  final File? archive;

  const LogsExportIdleState({this.archive});
}

final class LogsExportLoadingState extends LogsExportState {
  const LogsExportLoadingState();
}

final class LogsExportErrorState extends LogsExportState {
  @override
  final PresentationException error;

  const LogsExportErrorState(this.error);
}
