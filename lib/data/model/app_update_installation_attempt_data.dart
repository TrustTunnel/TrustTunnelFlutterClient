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

  factory AppUpdateInstallationAttemptData.fromJson(Map<String, dynamic> json) {
    final String operationId = json['operation'] as String;

    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(operationId)) {
      throw const FormatException('Invalid operation ID');
    }

    return AppUpdateInstallationAttemptData(
      operationId: operationId,
      sourceVersion: AppVersion.parse(json['sourceVersion'] as String),
      update: AvailableAppUpdateData.fromJson(json['update'] as Map<String, dynamic>),
      restoreServerId: json['restoreServerId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'operation': operationId,
    'sourceVersion': sourceVersion.toString(),
    'update': update.toJson(),
    'restoreServerId': restoreServerId,
  };
}
