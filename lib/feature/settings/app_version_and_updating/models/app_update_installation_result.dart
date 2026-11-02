import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_status.dart';

@immutable
final class AppUpdateInstallationResult {
  final String operationId;
  final AppUpdateInstallationStatus status;
  final bool installationApplied;
  final AppVersion version;
  final AppVersion previousVersion;
  final bool restartRequired;
  final String message;

  const AppUpdateInstallationResult({
    required this.operationId,
    required this.status,
    required this.installationApplied,
    required this.version,
    required this.previousVersion,
    required this.restartRequired,
    required this.message,
  });
}
