import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/datasources/app_updates_local_datasource.dart';
import 'package:trusttunnel/data/model/app_update_installation_attempt_data.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';

final class AppUpdatesLocalDataSourceImpl implements AppUpdatesLocalDataSource {
  final String _repositoryName;

  AppUpdatesLocalDataSourceImpl({
    required this._repositoryName,
  });

  Future<Directory> get _updatesDirectory async {
    final Directory supportDirectory = await getApplicationSupportDirectory();

    return Directory('${supportDirectory.path}/updates').create(recursive: true);
  }

  @override
  Future<File> getInstallerBundleFile(AvailableAppUpdateData update) async =>
      File('${(await _updatesDirectory).path}/${update.assetId}-${update.sha256}.exe');

  @override
  Future<void> prepareInstallerCache(AppVersion installedVersion) async {
    final Directory updatesDirectory = await _updatesDirectory;
    await for (final FileSystemEntity file in updatesDirectory.list()) {
      final bool isTemporaryFile = (file is File) && (file.path.endsWith('.part') || file.path.endsWith('.tmp'));

      if (isTemporaryFile) {
        await file.delete();
      }
    }

    final DownloadedInstallerBundleData? cachedBundle = await readInstallerBundle();
    final bool isObsoleteBundle = cachedBundle != null && cachedBundle.update.version.compareTo(installedVersion) <= 0;

    if (isObsoleteBundle) {
      await removeInstallerBundle();
    }
  }

  @override
  Future<DownloadedInstallerBundleData?> readInstallerBundle() async {
    final Map<String, dynamic>? json = await _readMetadata('bundle.json');

    if (json == null) {
      return null;
    }

    final AvailableAppUpdateData update = AvailableAppUpdateData.fromJson(json);
    _validateUpdateSource(update);
    final installerBundleFile = await getInstallerBundleFile(update);

    return DownloadedInstallerBundleData(
      update: update,
      path: installerBundleFile.path,
    );
  }

  @override
  Future<void> saveInstallerBundle(AvailableAppUpdateData update) => _writeMetadata(
    'bundle.json',
    update.toJson(),
  );

  @override
  Future<void> removeInstallerBundle() async {
    final Directory updatesDirectory = await _updatesDirectory;
    await for (final FileSystemEntity file in updatesDirectory.list()) {
      final bool isBundleFile = file is File && (file.path.endsWith('.exe') || file.path.endsWith('bundle.json'));

      if (isBundleFile) {
        await file.delete();
      }
    }
  }

  @override
  Future<bool> verifyInstallerBundle(DownloadedInstallerBundleData bundle) async {
    final File expectedFile = await getInstallerBundleFile(bundle.update);

    if (expectedFile.path != bundle.path) {
      return false;
    }

    final bool bundleExists = await expectedFile.exists();

    if (!bundleExists) {
      return false;
    }

    final int bundleSize = await expectedFile.length();

    if (bundleSize != bundle.update.size) {
      return false;
    }

    final Digest digest = await sha256.bind(expectedFile.openRead()).single;

    return digest.toString() == bundle.update.sha256;
  }

  @override
  Future<AppUpdateInstallationAttemptData?> readInstallationAttempt() async {
    final Map<String, dynamic>? json = await _readMetadata('attempt.json');

    if (json == null) {
      return null;
    }

    final AppUpdateInstallationAttemptData installationAttempt = AppUpdateInstallationAttemptData.fromJson(json);
    _validateUpdateSource(installationAttempt.update);

    return installationAttempt;
  }

  @override
  Future<void> saveInstallationAttempt(AppUpdateInstallationAttemptData attempt) =>
      _writeMetadata('attempt.json', attempt.toJson());

  @override
  Future<void> removeInstallationAttempt() async {
    final File file = File('${(await _updatesDirectory).path}/attempt.json');

    final bool metadataExists = await file.exists();

    if (metadataExists) {
      await file.delete();
    }
  }

  void _validateUpdateSource(AvailableAppUpdateData update) {
    if (update.source != _repositoryName) {
      throw const FormatException('Invalid update source');
    }
  }

  Future<Map<String, dynamic>?> _readMetadata(String fileName) async {
    final File file = File('${(await _updatesDirectory).path}/$fileName');

    final bool metadataExists = await file.exists();

    if (!metadataExists) {
      return null;
    }

    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<void> _writeMetadata(String fileName, Map<String, dynamic> json) async {
    final String metadataPath = '${(await _updatesDirectory).path}/$fileName';
    final File temporaryFile = File('$metadataPath.tmp');

    await temporaryFile.writeAsString(jsonEncode(json), flush: true);
    await temporaryFile.rename(metadataPath);
  }
}
