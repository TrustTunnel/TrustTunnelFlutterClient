import 'package:flutter/foundation.dart';

abstract class LogsManagerScopeController {
  abstract final bool loading;

  abstract final void Function({
    ValueChanged<String>? onArchiveReady,
    VoidCallback? onError,
  })
  exportLogs;

  abstract final void Function({
    required String subject,
    required String chooserTitle,
    required String filePath,
    VoidCallback? onDismissed,
    VoidCallback? onUnavailable,
  })
  shareLogs;

  abstract final void Function({
    VoidCallback? onDeleted,
  })
  deleteLogs;
}
