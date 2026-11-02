import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/data/converter/windows_app_update_installation_result_converter.dart';
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

    return const WindowsAppUpdateInstallationResultDecoder().convert(resultData);
  }
}
