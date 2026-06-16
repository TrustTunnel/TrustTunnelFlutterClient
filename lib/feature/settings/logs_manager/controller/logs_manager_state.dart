import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';

sealed class LogsManagerState {
  final ExportLogsArchive? archive;

  const LogsManagerState({
    this.archive,
  });

  const factory LogsManagerState.initial() = LogsManagerInitialState;

  const factory LogsManagerState.idle({
    ExportLogsArchive? archive,
  }) = LogsManagerIdleState;

  const factory LogsManagerState.loading({
    ExportLogsArchive? archive,
  }) = LogsManagerLoadingState;

  const factory LogsManagerState.error(
    PresentationException error, {
    ExportLogsArchive? archive,
  }) = LogsManagerErrorState;

  PresentationException? get error => switch (this) {
    LogsManagerErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is LogsManagerLoadingState;

  @override
  String toString() => 'LogsManagerState(type: $runtimeType, loading: $loading, hasArchive: ${archive != null})';
}

final class LogsManagerInitialState extends LogsManagerIdleState {
  const LogsManagerInitialState() : super();
}

final class LogsManagerIdleState extends LogsManagerState {
  const LogsManagerIdleState({
    super.archive,
  });
}

final class LogsManagerLoadingState extends LogsManagerState {
  const LogsManagerLoadingState({
    super.archive,
  });
}

final class LogsManagerErrorState extends LogsManagerState {
  @override
  final PresentationException error;

  const LogsManagerErrorState(
    this.error, {
    super.archive,
  });
}
