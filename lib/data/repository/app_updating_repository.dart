import 'dart:async';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:trusttunnel/common/error/model/file_download_exception.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/converter/app_update_failure_converter.dart';
import 'package:trusttunnel/data/converter/app_update_installation_attempt_converter.dart';
import 'package:trusttunnel/data/converter/app_update_installation_result_converter.dart';
import 'package:trusttunnel/data/converter/available_app_update_converter.dart';
import 'package:trusttunnel/data/converter/downloaded_installer_bundle_converter.dart';
import 'package:trusttunnel/data/datasources/app_update_installation_datasource.dart';
import 'package:trusttunnel/data/datasources/app_updates_local_datasource.dart';
import 'package:trusttunnel/data/datasources/releases_datasource.dart';
import 'package:trusttunnel/data/model/app_update_failure.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';
import 'package:trusttunnel/data/model/downloaded_installer_bundle_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_attempt.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_result.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/downloaded_installer_bundle.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/installer_bundle_preparation_status.dart';

abstract class AppUpdatingRepository {
  Future<AppVersion> get installedVersion;

  Future<AvailableAppUpdate?> findAvailableUpdate(AppVersion installedVersion);

  Future<void> prepareInstallerCache(AppVersion installedVersion);

  Future<DownloadedInstallerBundle?> readInstallerBundle();

  Future<void> removeInstallerBundle();

  Future<AppUpdateInstallationAttempt?> readInstallationAttempt();

  Future<void> saveInstallationAttempt(AppUpdateInstallationAttempt attempt);

  Future<void> removeInstallationAttempt();

  Future<AppUpdateInstallationResult?> readInstallationResult();

  Future<String> createInstallationOperationId();

  Future<void> launchInstaller(DownloadedInstallerBundle bundle, String operationId);

  Stream<InstallerBundlePreparationStatus> prepareInstallerBundle({
    required AvailableAppUpdate update,
    required bool forceDownload,
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

  Future<void> _installerCacheQueueFuture = Future<void>.value();

  Future<AppVersion>? _installedVersionFuture;

  @override
  Future<AppVersion> get installedVersion => _installedVersionFuture ??= PackageInfo.fromPlatform().then(
    (info) => AppVersion.parse(
      info.version.split('+').first,
    ),
  );

  @override
  Future<AvailableAppUpdate?> findAvailableUpdate(AppVersion installedVersion) async {
    try {
      final updateData = await _releasesDataSource.findAvailableUpdate(installedVersion);

      return updateData == null ? null : const AvailableAppUpdateDecoder().convert(updateData);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(AppUpdateCheckFailure(error), stackTrace);
    }
  }

  @override
  Future<void> prepareInstallerCache(AppVersion installedVersion) =>
      _withInstallerCache(() => _localDataSource.prepareInstallerCache(installedVersion));

  @override
  Future<DownloadedInstallerBundle?> readInstallerBundle() => _withInstallerCache(() async {
    final bundleData = await _localDataSource.readInstallerBundle();

    return bundleData == null ? null : const DownloadedInstallerBundleDecoder().convert(bundleData);
  });

  @override
  Future<void> removeInstallerBundle() => _withInstallerCache(_localDataSource.removeInstallerBundle);

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
  Future<String> createInstallationOperationId() async {
    try {
      return await _installationDataSourceProvider().createOperationId();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(const InstallerLaunchFailureDecoder().convert(error), stackTrace);
    }
  }

  @override
  Future<void> launchInstaller(DownloadedInstallerBundle bundle, String operationId) async {
    try {
      await _installationDataSourceProvider().launchInstaller(
        const DownloadedInstallerBundleEncoder().convert(bundle),
        operationId,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(const InstallerLaunchFailureDecoder().convert(error), stackTrace);
    }
  }

  @override
  Stream<InstallerBundlePreparationStatus> prepareInstallerBundle({
    required AvailableAppUpdate update,
    required bool forceDownload,
  }) => _InstallerPreparationStream(
    decodeFailure: const InstallerPreparationFailureDecoder().convert,
    prepare: (preparation) => _withInstallerCache(
      () => _runInstallerBundlePreparation(
        preparation: preparation,
        update: update,
        forceDownload: forceDownload,
      ),
    ),
  ).stream;

  Future<T> _withInstallerCache<T>(Future<T> Function() operation) {
    final Future<T> cacheOperationFuture = _installerCacheQueueFuture.then((_) => operation());
    // A cancelled or failed attempt must release the cache for the next operation.
    _installerCacheQueueFuture = cacheOperationFuture.then<void>((_) {}, onError: (Object _, StackTrace _) {});

    return cacheOperationFuture;
  }

  Future<void> _runInstallerBundlePreparation({
    required _InstallerPreparationStream preparation,
    required AvailableAppUpdate update,
    required bool forceDownload,
  }) async {
    preparation.checkCancellation();
    preparation.setStatus(const InstallerBundlePreparationStatus.preparing());
    final DownloadedInstallerBundle? cachedBundle = await _reuseOrRemoveCachedBundle(
      preparation: preparation,
      update: update,
      forceDownload: forceDownload,
    );
    preparation.checkCancellation();

    if (cachedBundle != null) {
      preparation.setStatus(InstallerBundlePreparationStatus.ready(cachedBundle));

      return;
    }

    final DownloadedInstallerBundle bundle = await _downloadAndVerifyInstaller(preparation, update);
    preparation.checkCancellation();
    preparation.setStatus(InstallerBundlePreparationStatus.ready(bundle));
  }

  Future<DownloadedInstallerBundle?> _reuseOrRemoveCachedBundle({
    required _InstallerPreparationStream preparation,
    required AvailableAppUpdate update,
    required bool forceDownload,
  }) async {
    try {
      if (!forceDownload) {
        final DownloadedInstallerBundleData? bundleData = await _localDataSource.readInstallerBundle();
        preparation.checkCancellation();
        final DownloadedInstallerBundle? cachedBundle = bundleData == null
            ? null
            : const DownloadedInstallerBundleDecoder().convert(bundleData);
        final bool matchesSelectedUpdate = cachedBundle != null && cachedBundle.update.hasSameInstallerBundle(update);

        if (matchesSelectedUpdate) {
          final bool verified = await _localDataSource.verifyInstallerBundle(bundleData!);
          preparation.checkCancellation();

          if (verified) {
            return cachedBundle;
          }
        }
      }

      preparation.checkCancellation();
      await _localDataSource.removeInstallerBundle();

      return null;
    } on FileDownloadCancelledException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(InstallerBundlePreparationException(error), stackTrace);
    }
  }

  Future<DownloadedInstallerBundle> _downloadAndVerifyInstaller(
    _InstallerPreparationStream preparation,
    AvailableAppUpdate update,
  ) async {
    final AvailableAppUpdateData updateData = const AvailableAppUpdateEncoder().convert(update);
    final File temporaryFile = await _localDataSource.getTemporaryInstallerBundleFile(updateData);
    Object? failure;
    late final DownloadedInstallerBundle bundle;

    try {
      preparation.checkCancellation();
      preparation.setStatus(InstallerBundlePreparationStatus.downloading(receivedBytes: 0, totalBytes: update.size));
      await for (final int receivedBytes in preparation.bindDownload(
        _releasesDataSource.downloadInstallerBundle(
          assetId: update.assetId,
          expectedSize: update.size,
          destinationPath: temporaryFile.path,
        ),
      )) {
        preparation.setStatus(
          InstallerBundlePreparationStatus.downloading(receivedBytes: receivedBytes, totalBytes: update.size),
        );
      }
      preparation.checkCancellation();
      preparation.setStatus(const InstallerBundlePreparationStatus.verifying());
      final bool verified = await _localDataSource.verifyInstallerFile(path: temporaryFile.path, update: updateData);
      preparation.checkCancellation();

      if (!verified) {
        throw const DamagedInstallerBundleException();
      }

      // Once caching starts, finish the file and metadata together. A late cancellation
      // can keep a valid cache, but cannot publish a result or launch the installer.
      final DownloadedInstallerBundleData bundleData = await _localDataSource.cacheInstallerBundle(
        update: updateData,
        temporaryFile: temporaryFile,
      );
      bundle = const DownloadedInstallerBundleDecoder().convert(bundleData);
    } catch (error) {
      failure = error;
      rethrow;
    } finally {
      try {
        await _localDataSource.removeTemporaryInstallerBundle(temporaryFile);
      } catch (error, stackTrace) {
        if (failure == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      }
    }

    return bundle;
  }
}

/// Owns a preparation subscription and waits for download cleanup on cancellation.
/// The repository supplies the preparation procedure and all cache decisions.
final class _InstallerPreparationStream {
  final Future<void> Function(_InstallerPreparationStream preparation) _prepare;
  final AppUpdateFailure Function(Object error) _decodeFailure;

  _InstallerPreparationStream({
    required this._prepare,
    required this._decodeFailure,
  });

  late final StreamController<InstallerBundlePreparationStatus> _statuses =
      StreamController<InstallerBundlePreparationStatus>(
        onListen: () {
          _preparationCompletionFuture = _run();
        },
        onCancel: _cancel,
      );
  late final Future<AsyncError?> _preparationCompletionFuture;
  StreamIterator<int>? _download;
  Future<void>? _downloadCancellationFuture;

  Stream<InstallerBundlePreparationStatus> get stream => _statuses.stream;

  void checkCancellation() {
    if (!_statuses.hasListener) {
      throw const FileDownloadCancelledException();
    }
  }

  void setStatus(InstallerBundlePreparationStatus status) {
    if (_statuses.hasListener) {
      _statuses.add(status);
    }
  }

  Stream<int> bindDownload(Stream<int> download) async* {
    checkCancellation();
    final StreamIterator<int> chunks = StreamIterator<int>(download);
    _download = chunks;

    try {
      while (true) {
        final bool hasNext = await chunks.moveNext();
        checkCancellation();

        if (!hasNext) {
          return;
        }

        yield chunks.current;
      }
    } finally {
      await _stopDownload();
    }
  }

  // moveNext can finish before source cleanup. Both paths must await the same future.
  Future<void> _stopDownload() => _downloadCancellationFuture ??= _download?.cancel() ?? Future<void>.value();

  Future<void> _cancel() async {
    if (_statuses.isClosed) {
      return;
    }

    try {
      await _stopDownload();
    } finally {
      final AsyncError? failure = await _preparationCompletionFuture;

      if (failure != null && failure.error is! AppUpdateCancelledFailure) {
        Error.throwWithStackTrace(failure.error, failure.stackTrace);
      }
    }
  }

  Future<AsyncError?> _run() async {
    try {
      await _prepare(this);

      return null;
    } catch (error, stackTrace) {
      final AppUpdateFailure failure = _decodeFailure(error);

      if (_statuses.hasListener) {
        _statuses.addError(failure, stackTrace);
      }

      return AsyncError(failure, stackTrace);
    } finally {
      // Stream delivery must not keep the cache locked or block cancellation.
      unawaited(_statuses.close());
    }
  }
}
