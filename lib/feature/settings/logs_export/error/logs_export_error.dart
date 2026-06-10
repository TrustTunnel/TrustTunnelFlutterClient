import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';

sealed class LogsExportPresentationError implements PresentationError {
  final PresentationError originalError;

  const LogsExportPresentationError(this.originalError);

  @override
  String toLocalizedString(BuildContext context) => originalError.toLocalizedString(context);
}

final class LogsExportFailedPresentationError extends LogsExportPresentationError {
  const LogsExportFailedPresentationError(super.originalError);
}

final class LogsShareFailedPresentationError extends LogsExportPresentationError {
  const LogsShareFailedPresentationError(super.originalError);
}
