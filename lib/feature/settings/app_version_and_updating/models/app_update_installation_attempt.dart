import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

@immutable
final class AppUpdateInstallationAttempt {
  final String operationId;
  final AppVersion sourceVersion;
  final AvailableAppUpdate update;
  final String? restoreServerId;

  const AppUpdateInstallationAttempt({
    required this.operationId,
    required this.sourceVersion,
    required this.update,
    required this.restoreServerId,
  });
}
