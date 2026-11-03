import 'dart:convert';

import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/converter/app_update_installation_attempt_metadata_codec.dart';
import 'package:trusttunnel/data/model/app_update_installation_result_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_status.dart';

/// Validates the result returned by the Windows installer channel.
final class WindowsAppUpdateInstallationResultDecoder
    extends Converter<Map<String, dynamic>, AppUpdateInstallationResultData> {
  const WindowsAppUpdateInstallationResultDecoder();

  @override
  AppUpdateInstallationResultData convert(Map<String, dynamic> input) {
    final String operationId = const AppUpdateOperationIdDecoder().convert(input['operation'] as String);
    final bool validInstallationApplied = const ['true', 'false'].contains(input['committed']);
    final bool validRestartRequired = const ['true', 'false'].contains(input['restart_required']);
    final AppUpdateInstallationStatus status = AppUpdateInstallationStatus.values.firstWhere(
      (status) => status.value == input['status'],
      orElse: () => throw const FormatException('Invalid installer result'),
    );

    if (!validInstallationApplied || !validRestartRequired) {
      throw const FormatException('Invalid installer result');
    }

    return AppUpdateInstallationResultData(
      operationId: operationId,
      status: status,
      installationApplied: input['committed'] == 'true',
      version: AppVersion.parse(input['version'] as String),
      previousVersion: AppVersion.parse(input['previous_version'] as String),
      restartRequired: input['restart_required'] == 'true',
      message: input['message'] as String,
    );
  }
}
