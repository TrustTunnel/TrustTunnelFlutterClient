import 'package:trusttunnel/data/model/app_update_installation_result_data.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';

abstract interface class AppUpdateInstallationDataSource {
  Future<String> createOperationId();

  Future<void> launchInstaller(DownloadedInstallerBundleData bundle, String operationId);

  Future<AppUpdateInstallationResultData?> readInstallationResult();
}
