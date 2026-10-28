import 'dart:io';

import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/model/app_update_installation_attempt_data.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';

abstract interface class AppUpdatesLocalDataSource {
  Future<File> getInstallerBundleFile(AvailableAppUpdateData update);

  Future<void> prepareInstallerCache(AppVersion installedVersion);

  Future<DownloadedInstallerBundleData?> readInstallerBundle();

  Future<void> saveInstallerBundle(AvailableAppUpdateData update);

  Future<void> removeInstallerBundle();

  Future<bool> verifyInstallerBundle(DownloadedInstallerBundleData bundle);

  Future<AppUpdateInstallationAttemptData?> readInstallationAttempt();

  Future<void> saveInstallationAttempt(AppUpdateInstallationAttemptData attempt);

  Future<void> removeInstallationAttempt();
}
