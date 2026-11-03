import 'dart:convert';

import 'package:trusttunnel/data/converter/available_app_update_converter.dart';
import 'package:trusttunnel/data/model/app_update_installation_attempt_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_attempt.dart';

final class AppUpdateInstallationAttemptEncoder
    extends Converter<AppUpdateInstallationAttempt, AppUpdateInstallationAttemptData> {
  const AppUpdateInstallationAttemptEncoder();

  @override
  AppUpdateInstallationAttemptData convert(AppUpdateInstallationAttempt value) => AppUpdateInstallationAttemptData(
    operationId: value.operationId,
    sourceVersion: value.sourceVersion,
    update: const AvailableAppUpdateEncoder().convert(value.update),
    restoreServerId: value.restoreServerId,
  );
}

final class AppUpdateInstallationAttemptDecoder
    extends Converter<AppUpdateInstallationAttemptData, AppUpdateInstallationAttempt> {
  const AppUpdateInstallationAttemptDecoder();

  @override
  AppUpdateInstallationAttempt convert(AppUpdateInstallationAttemptData value) => AppUpdateInstallationAttempt(
    operationId: value.operationId,
    sourceVersion: value.sourceVersion,
    update: const AvailableAppUpdateDecoder().convert(value.update),
    restoreServerId: value.restoreServerId,
  );
}
