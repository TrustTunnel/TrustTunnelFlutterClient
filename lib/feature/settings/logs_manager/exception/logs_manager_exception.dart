import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class LogsManagerPresentationException implements PresentationException {
  final PresentationException originalError;

  const LogsManagerPresentationException(this.originalError);

  @override
  String toLocalizedString(BuildContext context) => originalError.toLocalizedString(context);
}

final class LogsExportFailedPresentationException extends LogsManagerPresentationException {
  const LogsExportFailedPresentationException(super.originalError);
}

final class LogsShareFailedPresentationException extends LogsManagerPresentationException {
  const LogsShareFailedPresentationException(super.originalError);
}

final class LogsDeleteFailedPresentationException extends LogsManagerPresentationException {
  const LogsDeleteFailedPresentationException(super.originalError);
}
