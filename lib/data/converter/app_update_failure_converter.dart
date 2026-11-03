import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:trusttunnel/common/error/model/file_download_exception.dart';
import 'package:trusttunnel/data/model/app_update_failure.dart';

final class DamagedInstallerBundleException implements Exception {
  const DamagedInstallerBundleException();
}

final class InstallerBundlePreparationException implements Exception {
  final Object cause;

  const InstallerBundlePreparationException(this.cause);

  @override
  String toString() => 'InstallerBundlePreparationException: $cause';
}

final class InstallerPreparationFailureDecoder extends Converter<Object, AppUpdateFailure> {
  const InstallerPreparationFailureDecoder();

  @override
  AppUpdateFailure convert(Object input) => switch (input) {
    AppUpdateFailure() => input,
    FileDownloadCleanupException(:final cause) => _withCause(convert(cause), input),
    FileDownloadCancelledException() => AppUpdateCancelledFailure(input),
    InstallerBundlePreparationException() => AppUpdateInstallationFailure(input),
    DamagedInstallerBundleException() || FileDownloadSizeException() => AppUpdateDamagedFailure(input),
    _ => AppUpdateDownloadFailure(input),
  };

  AppUpdateFailure _withCause(AppUpdateFailure failure, Object cause) => switch (failure) {
    AppUpdateCheckFailure() => AppUpdateCheckFailure(cause),
    AppUpdateDownloadFailure() => AppUpdateDownloadFailure(cause),
    AppUpdateDamagedFailure() => AppUpdateDamagedFailure(cause),
    AppUpdatePermissionFailure() => AppUpdatePermissionFailure(cause),
    AppUpdateInstallationFailure() => AppUpdateInstallationFailure(cause),
    AppUpdateCancelledFailure() => AppUpdateDownloadFailure(cause),
  };
}

final class InstallerLaunchFailureDecoder extends Converter<Object, AppUpdateFailure> {
  const InstallerLaunchFailureDecoder();

  @override
  AppUpdateFailure convert(Object input) => switch (input) {
    AppUpdateFailure() => input,
    PlatformException(code: 'permission-denied') => AppUpdatePermissionFailure(input),
    PlatformException(code: 'damaged-file') => AppUpdateDamagedFailure(input),
    _ => AppUpdateInstallationFailure(input),
  };
}
