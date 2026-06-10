import 'package:flutter/foundation.dart';

@immutable
sealed class LogsExportAction {
  const LogsExportAction();

  const factory LogsExportAction.archiveReady() = LogsExportArchiveReadyAction;

  const factory LogsExportAction.cancelled() = LogsExportCancelledAction;

  const factory LogsExportAction.shareDismissed() = LogsExportShareDismissedAction;

  const factory LogsExportAction.shareUnavailable() = LogsExportShareUnavailableAction;
}

@immutable
final class LogsExportArchiveReadyAction extends LogsExportAction {
  const LogsExportArchiveReadyAction();
}

@immutable
final class LogsExportCancelledAction extends LogsExportAction {
  const LogsExportCancelledAction();
}

@immutable
final class LogsExportShareDismissedAction extends LogsExportAction {
  const LogsExportShareDismissedAction();
}

@immutable
final class LogsExportShareUnavailableAction extends LogsExportAction {
  const LogsExportShareUnavailableAction();
}
