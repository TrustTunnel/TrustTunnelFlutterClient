import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/localization/localization.dart';

sealed class AppUpdateException implements PresentationException {
  const AppUpdateException();

  String? toLocalizedTitle(BuildContext context) => null;
}

final class AppUpdateCheckException extends AppUpdateException {
  const AppUpdateCheckException();

  @override
  String toLocalizedString(BuildContext context) => context.ln.updateCheckError;
}

final class AppUpdateDownloadException extends AppUpdateException {
  const AppUpdateDownloadException();

  @override
  String toLocalizedString(BuildContext context) => context.ln.updateDownloadErrorDescription;

  @override
  String toLocalizedTitle(BuildContext context) => context.ln.updateDownloadError;
}

final class AppUpdateDamagedException extends AppUpdateException {
  const AppUpdateDamagedException();

  @override
  String toLocalizedString(BuildContext context) => context.ln.updateDamagedError;

  @override
  String toLocalizedTitle(BuildContext context) => context.ln.updateInstallError;
}

final class AppUpdatePermissionException extends AppUpdateException {
  const AppUpdatePermissionException();

  @override
  String toLocalizedString(BuildContext context) => context.ln.updatePermissionError;
}

final class AppUpdateInstallationException extends AppUpdateException {
  const AppUpdateInstallationException();

  @override
  String toLocalizedString(BuildContext context) => context.ln.updateInstallError;
}
