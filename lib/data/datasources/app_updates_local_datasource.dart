import 'dart:io';

import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/model/app_update_installation_attempt_data.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';

abstract interface class AppUpdatesLocalDataSource {
  Future<File> createTemporaryInstallerBundleFile(AvailableAppUpdateData update);

  Future<void> prepareInstallerCache(AppVersion installedVersion);

  Future<DownloadedInstallerBundleData?> readInstallerBundle();

  Future<DownloadedInstallerBundleData> cacheInstallerBundle({
    required AvailableAppUpdateData update,
    required File temporaryFile,
  });

  Future<void> removeTemporaryInstallerBundle(File temporaryFile);

  Future<void> removeInstallerBundle();

  Future<bool> verifyInstallerBundle(DownloadedInstallerBundleData bundle);

  Future<bool> verifyInstallerFile({required String path, required AvailableAppUpdateData update});

  Future<AppUpdateInstallationAttemptData?> readInstallationAttempt();

  Future<void> saveInstallationAttempt(AppUpdateInstallationAttemptData attempt);

  Future<void> removeInstallationAttempt();
}
