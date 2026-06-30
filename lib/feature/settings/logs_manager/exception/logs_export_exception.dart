import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class LogsExportPresentationException implements PresentationException {
  final PresentationException originalError;

  const LogsExportPresentationException(this.originalError);

  @override
  String toLocalizedString(BuildContext context) => originalError.toLocalizedString(context);
}

final class LogsExportFailedPresentationException extends LogsExportPresentationException {
  const LogsExportFailedPresentationException(super.originalError);
}

final class LogsShareFailedPresentationException extends LogsExportPresentationException {
  const LogsShareFailedPresentationException(super.originalError);
}

// Deprecated: use logs_manager_exception.dart instead.
