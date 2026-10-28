import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/converter/app_update_installation_attempt_converter.dart';
import 'package:trusttunnel/data/converter/app_update_installation_result_converter.dart';
import 'package:trusttunnel/data/converter/available_app_update_converter.dart';
import 'package:trusttunnel/data/converter/downloaded_installer_bundle_converter.dart';
import 'package:trusttunnel/data/datasources/app_update_installation_datasource.dart';
import 'package:trusttunnel/data/datasources/app_updates_local_datasource.dart';
import 'package:trusttunnel/data/datasources/releases_datasource.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_attempt.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_result.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/downloaded_installer_bundle.dart';

final class DamagedInstallerBundleException implements Exception {
  const DamagedInstallerBundleException();
}

final class InstallerBundleDownloadCancelledException implements Exception {
  const InstallerBundleDownloadCancelledException();
}

abstract class AppUpdatingRepository {
  Future<AppVersion> get installedVersion;

  Future<AvailableAppUpdate?> findAvailableUpdate(AppVersion installedVersion);

  Future<void> prepareInstallerCache(AppVersion installedVersion);

  Future<DownloadedInstallerBundle?> readInstallerBundle();

  Future<void> removeInstallerBundle();

  Future<bool> verifyInstallerBundle(DownloadedInstallerBundle bundle);

  Future<AppUpdateInstallationAttempt?> readInstallationAttempt();

  Future<void> saveInstallationAttempt(AppUpdateInstallationAttempt attempt);

  Future<void> removeInstallationAttempt();

  Future<AppUpdateInstallationResult?> readInstallationResult();

  Future<String> createInstallationOperationId();

  Future<void> launchInstaller(DownloadedInstallerBundle bundle, String operationId);

  Future<DownloadedInstallerBundle> downloadInstallerBundle({
    required AvailableAppUpdate update,
    required Future<void> cancellation,
    required bool Function() isCancelled,
    required void Function(double) onProgress,
    required int attemptId,
    required void Function() onVerifying,
  });
}

final class AppUpdatingRepositoryImpl implements AppUpdatingRepository {
  final ReleasesDataSource _releasesDataSource;
  final AppUpdatesLocalDataSource _localDataSource;
  final AppUpdateInstallationDataSource Function() _installationDataSourceProvider;

  AppUpdatingRepositoryImpl({
    required this._releasesDataSource,
    required this._localDataSource,
    required this._installationDataSourceProvider,
  });

  Future<AppVersion>? _installedVersion;

  @override
  Future<AppVersion> get installedVersion => _installedVersion ??= PackageInfo.fromPlatform().then(
    (info) => AppVersion.parse(
      info.version.split('+').first,
    ),
  );

  @override
  Future<AvailableAppUpdate?> findAvailableUpdate(AppVersion installedVersion) async {
    final updateData = await _releasesDataSource.findAvailableUpdate(installedVersion);

    return updateData == null ? null : const AvailableAppUpdateDecoder().convert(updateData);
  }

  @override
  Future<void> prepareInstallerCache(AppVersion installedVersion) =>
      _localDataSource.prepareInstallerCache(installedVersion);

  @override
  Future<DownloadedInstallerBundle?> readInstallerBundle() async {
    final bundleData = await _localDataSource.readInstallerBundle();

    return bundleData == null ? null : const DownloadedInstallerBundleDecoder().convert(bundleData);
  }

  @override
  Future<void> removeInstallerBundle() => _localDataSource.removeInstallerBundle();

  @override
  Future<bool> verifyInstallerBundle(DownloadedInstallerBundle bundle) =>
      _localDataSource.verifyInstallerBundle(const DownloadedInstallerBundleEncoder().convert(bundle));

  @override
  Future<AppUpdateInstallationAttempt?> readInstallationAttempt() async {
    final attemptData = await _localDataSource.readInstallationAttempt();

    return attemptData == null ? null : const AppUpdateInstallationAttemptDecoder().convert(attemptData);
  }

  @override
  Future<void> saveInstallationAttempt(AppUpdateInstallationAttempt attempt) =>
      _localDataSource.saveInstallationAttempt(const AppUpdateInstallationAttemptEncoder().convert(attempt));

  @override
  Future<void> removeInstallationAttempt() => _localDataSource.removeInstallationAttempt();

  @override
  Future<AppUpdateInstallationResult?> readInstallationResult() async {
    final resultData = await _installationDataSourceProvider().readInstallationResult();

    return resultData == null ? null : const AppUpdateInstallationResultDecoder().convert(resultData);
  }

  @override
  Future<String> createInstallationOperationId() => _installationDataSourceProvider().createOperationId();

  @override
  Future<void> launchInstaller(DownloadedInstallerBundle bundle, String operationId) =>
      _installationDataSourceProvider().launchInstaller(
        const DownloadedInstallerBundleEncoder().convert(bundle),
        operationId,
      );

  @override
  Future<DownloadedInstallerBundle> downloadInstallerBundle({
    required AvailableAppUpdate update,
    required Future<void> cancellation,
    required bool Function() isCancelled,
    required void Function(double) onProgress,
    required int attemptId,
    required void Function() onVerifying,
  }) async {
    final updateData = const AvailableAppUpdateEncoder().convert(update);

    final File destinationFile = await _localDataSource.getInstallerBundleFile(updateData);
    final File temporaryFile = File('${destinationFile.path}.$attemptId.part');

    RandomAccessFile? bundleWriter;

    try {
      _ensureDownloadActive(isCancelled);

      bundleWriter = await temporaryFile.open(mode: FileMode.write);
      int receivedBytes = 0;
      int reportedPercentage = -1;

      await for (final List<int> chunk in _releasesDataSource.openInstallerBundle(
        assetId: update.assetId,
        cancellation: cancellation,
      )) {
        _ensureDownloadActive(isCancelled);
        receivedBytes += chunk.length;

        if (receivedBytes > update.size) {
          throw const DamagedInstallerBundleException();
        }

        await bundleWriter.writeFrom(chunk);
        final int nextPercentage = (receivedBytes * 100 ~/ update.size).clamp(0, 100);

        if (nextPercentage != reportedPercentage) {
          reportedPercentage = nextPercentage;
          onProgress((receivedBytes / update.size).clamp(0.0, 1.0));
        }
      }

      await bundleWriter.flush();
      await bundleWriter.close();
      bundleWriter = null;
      _ensureDownloadActive(isCancelled);

      if (receivedBytes != update.size) {
        throw const DamagedInstallerBundleException();
      }

      onVerifying();
      final String bundleDigest = await _calculateBundleHash(temporaryFile);
      _ensureDownloadActive(isCancelled);

      if (bundleDigest != update.sha256) {
        throw const DamagedInstallerBundleException();
      }

      await temporaryFile.rename(destinationFile.path);
      await _localDataSource.saveInstallerBundle(updateData);

      return DownloadedInstallerBundle(update: update, path: destinationFile.path);
    } finally {
      try {
        await bundleWriter?.close();
      } finally {
        final bool temporaryFileExists = await temporaryFile.exists();

        if (temporaryFileExists) {
          await temporaryFile.delete();
        }
      }
    }
  }

  void _ensureDownloadActive(bool Function() isCancelled) {
    if (isCancelled()) {
      throw const InstallerBundleDownloadCancelledException();
    }
  }

  Future<String> _calculateBundleHash(File file) async => (await sha256.bind(file.openRead()).single).toString();
}
