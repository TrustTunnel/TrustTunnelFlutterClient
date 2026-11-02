import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

@immutable
final class AppUpdateInstallationAttemptData {
  final String operationId;
  final AppVersion sourceVersion;
  final AvailableAppUpdateData update;
  final String? restoreServerId;

  const AppUpdateInstallationAttemptData({
    required this.operationId,
    required this.sourceVersion,
    required this.update,
    required this.restoreServerId,
  });
}
