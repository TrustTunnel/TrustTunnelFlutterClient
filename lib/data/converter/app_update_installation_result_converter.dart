import 'dart:convert';

import 'package:trusttunnel/data/model/app_update_installation_result_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_result.dart';

final class AppUpdateInstallationResultEncoder
    extends Converter<AppUpdateInstallationResult, AppUpdateInstallationResultData> {
  const AppUpdateInstallationResultEncoder();

  @override
  AppUpdateInstallationResultData convert(AppUpdateInstallationResult value) => AppUpdateInstallationResultData(
    operationId: value.operationId,
    status: value.status,
    installationApplied: value.installationApplied,
    version: value.version,
    previousVersion: value.previousVersion,
    restartRequired: value.restartRequired,
    message: value.message,
  );
}

final class AppUpdateInstallationResultDecoder
    extends Converter<AppUpdateInstallationResultData, AppUpdateInstallationResult> {
  const AppUpdateInstallationResultDecoder();

  @override
  AppUpdateInstallationResult convert(AppUpdateInstallationResultData value) => AppUpdateInstallationResult(
    operationId: value.operationId,
    status: value.status,
    installationApplied: value.installationApplied,
    version: value.version,
    previousVersion: value.previousVersion,
    restartRequired: value.restartRequired,
    message: value.message,
  );
}
