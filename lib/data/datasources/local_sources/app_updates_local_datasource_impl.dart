import 'dart:convert';
import 'dart:io';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/utils/file_utils.dart';
import 'package:trusttunnel/data/converter/app_update_installation_attempt_metadata_codec.dart';
import 'package:trusttunnel/data/converter/available_app_update_metadata_codec.dart';
import 'package:trusttunnel/data/datasources/app_updates_local_datasource.dart';
import 'package:trusttunnel/data/model/app_update_installation_attempt_data.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';

final class AppUpdatesLocalDataSourceImpl implements AppUpdatesLocalDataSource {
  final String _repositoryName;

  AppUpdatesLocalDataSourceImpl({
    required this._repositoryName,
  });

  int _temporaryFileId = 0;

  Future<Directory> get _updatesDirectory async {
    final Directory supportDirectory = await getApplicationSupportDirectory();

    return Directory('${supportDirectory.path}/updates').create(recursive: true);
  }

  @override
  Future<File> getTemporaryInstallerBundleFile(AvailableAppUpdateData update) async {
    final File destinationFile = await _getInstallerBundleFile(update);

    return File('${destinationFile.path}.${++_temporaryFileId}.part');
  }

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

    final AvailableAppUpdateData update = const AvailableAppUpdateMetadataCodec().decode(json);
    _validateUpdateSource(update);
    final File installerBundleFile = await _getInstallerBundleFile(update);

    return DownloadedInstallerBundleData(
      update: update,
      path: installerBundleFile.path,
    );
  }

  @override
  Future<DownloadedInstallerBundleData> cacheInstallerBundle({
    required AvailableAppUpdateData update,
    required File temporaryFile,
  }) async {
    final File destinationFile = await _getInstallerBundleFile(update);
    bool renamed = false;

    try {
      await temporaryFile.rename(destinationFile.path);
      renamed = true;
      await _writeMetadata('bundle.json', const AvailableAppUpdateMetadataCodec().encode(update));

      return DownloadedInstallerBundleData(update: update, path: destinationFile.path);
    } catch (error, stackTrace) {
      // A file and its metadata cannot be saved in one filesystem transaction.
      // Remove this attempt's incomplete cache before another attempt can use it.
      if (renamed) {
        await _removeIncompleteInstallerCache(destinationFile);
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> removeTemporaryInstallerBundle(File temporaryFile) => FileUtils.deleteIfExists(temporaryFile);

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
    final File expectedFile = await _getInstallerBundleFile(bundle.update);

    if (expectedFile.path != bundle.path) {
      return false;
    }

    return verifyInstallerFile(path: expectedFile.path, update: bundle.update);
  }

  @override
  Future<bool> verifyInstallerFile({
    required String path,
    required AvailableAppUpdateData update,
  }) => compute(
    FileUtils.verifyFile,
    (path: path, size: update.size, sha256: update.sha256),
    debugLabel: 'verify-installer-bundle',
  );

  @override
  Future<AppUpdateInstallationAttemptData?> readInstallationAttempt() async {
    final Map<String, dynamic>? json = await _readMetadata('attempt.json');

    if (json == null) {
      return null;
    }

    final AppUpdateInstallationAttemptData installationAttempt = const AppUpdateInstallationAttemptMetadataCodec()
        .decode(json);
    _validateUpdateSource(installationAttempt.update);

    return installationAttempt;
  }

  @override
  Future<void> saveInstallationAttempt(AppUpdateInstallationAttemptData attempt) =>
      _writeMetadata('attempt.json', const AppUpdateInstallationAttemptMetadataCodec().encode(attempt));

  @override
  Future<void> removeInstallationAttempt() async {
    final File file = File('${(await _updatesDirectory).path}/attempt.json');

    final bool metadataExists = await file.exists();

    if (metadataExists) {
      await file.delete();
    }
  }

  Future<File> _getInstallerBundleFile(AvailableAppUpdateData update) async =>
      File('${(await _updatesDirectory).path}/${update.assetId}-${update.sha256}.exe');

  void _validateUpdateSource(AvailableAppUpdateData update) {
    if (update.source != _repositoryName) {
      throw const FormatException('Invalid update source');
    }
  }

  Future<void> _removeIncompleteInstallerCache(File destinationFile) async {
    final Directory updatesDirectory = destinationFile.parent;
    final List<File> files = [
      destinationFile,
      File('${updatesDirectory.path}/bundle.json'),
      File('${updatesDirectory.path}/bundle.json.tmp'),
    ];

    for (final File file in files) {
      try {
        await FileUtils.deleteIfExists(file);
      } catch (error, stackTrace) {
        logger.logError(
          'Unable to remove incomplete installer cache',
          error: error,
          stackTrace: stackTrace,
        );
      }
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
