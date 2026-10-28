import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/datasources/app_update_installation_datasource.dart';
import 'package:trusttunnel/data/model/app_update_installation_result_data.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';

final class WindowsAppUpdateInstallationDataSource implements AppUpdateInstallationDataSource {
  static const MethodChannel _channel = MethodChannel('trusttunnel/windows_update');

  WindowsAppUpdateInstallationDataSource()
    : assert(
        defaultTargetPlatform == TargetPlatform.windows,
        'App updates are currently supported only on Windows',
      );

  @override
  Future<String> createOperationId() async => (await _channel.invokeMethod<String>('createOperation'))!;

  @override
  Future<void> launchInstaller(DownloadedInstallerBundleData bundle, String operationId) =>
      _channel.invokeMethod<void>('launchInstaller', {
        'path': bundle.path,
        'operation': operationId,
        'version': bundle.update.version.toString(),
        'sha256': bundle.update.sha256,
        'size': bundle.update.size,
      });

  @override
  Future<AppUpdateInstallationResultData?> readInstallationResult() async {
    final Map<String, dynamic>? resultData = await _channel.invokeMapMethod<String, dynamic>('readResult');

    if (resultData == null) {
      return null;
    }

    final bool isOperationFormatValid = RegExp(r'^[a-f0-9]{32}$').hasMatch(resultData['operation'] as String);
    final bool isCommittedFormatValid = const ['true', 'false'].contains(resultData['committed']);
    final bool isRestartRequiredFormatValid = const ['true', 'false'].contains(resultData['restart_required']);
    final bool isStatusFormatValid = const [
      'success',
      'failed',
      'rolled_back',
      'rollback_failed',
      'launch_failed',
      'rollback_launch_failed',
      'autostart_failed',
    ].contains(resultData['status']);

    if (!isOperationFormatValid || !isCommittedFormatValid || !isRestartRequiredFormatValid || !isStatusFormatValid) {
      throw const FormatException('Invalid installer result');
    }

    return AppUpdateInstallationResultData(
      operationId: resultData['operation'] as String,
      status: resultData['status'] as String,
      committed: resultData['committed'] == 'true',
      version: AppVersion.parse(resultData['version'] as String),
      previousVersion: AppVersion.parse(resultData['previous_version'] as String),
      restartRequired: resultData['restart_required'] == 'true',
      message: resultData['message'] as String,
    );
  }
}
