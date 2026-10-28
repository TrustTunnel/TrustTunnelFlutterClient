import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';

@immutable
final class AppUpdateInstallationResult {
  final String operationId;
  final String status;
  final bool committed;
  final AppVersion version;
  final AppVersion previousVersion;
  final bool restartRequired;
  final String message;

  const AppUpdateInstallationResult({
    required this.operationId,
    required this.status,
    required this.committed,
    required this.version,
    required this.previousVersion,
    required this.restartRequired,
    required this.message,
  });
}
