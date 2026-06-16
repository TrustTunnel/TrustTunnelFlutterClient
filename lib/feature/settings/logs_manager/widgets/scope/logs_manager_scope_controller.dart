import 'package:flutter/foundation.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';

abstract class LogsManagerScopeController {
  abstract final bool loading;

  abstract final ExportLogsArchive? archive;

  abstract final void Function({
    VoidCallback? onArchiveReady,
  })
  exportLogs;

  abstract final void Function({
    required String subject,
    required String chooserTitle,
    VoidCallback? onDismissed,
    VoidCallback? onUnavailable,
  })
  shareLogs;

  abstract final void Function({
    VoidCallback? onDeleted,
  })
  deleteLogs;
}
