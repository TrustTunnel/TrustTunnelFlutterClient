import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/repository/app_updating_repository.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/controller/app_version_and_updating_state.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_attempt.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_result.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/downloaded_installer_bundle.dart';

final class AppVersionAndUpdatingController extends BaseStateController<AppVersionAndUpdatingState>
    with SequentialControllerHandler {
  final AppUpdatingRepository _repository;
  final Duration _checkInterval;

  AppVersionAndUpdatingController({
    required this._repository,
    required this._checkInterval,
    required bool updatesSupported,
  }) : assert(
         !updatesSupported || defaultTargetPlatform == TargetPlatform.windows,
         'App updates are currently supported only on Windows',
       ),
       super(
         initialState: AppVersionAndUpdatingState.initial(
           updatesSupported: updatesSupported,
         ),
       );

  void loadInitialDataAndStartUpdateChecks() => handle(() {
    unawaited(
      _repository.installedVersion.then(
        _onInstalledVersionLoaded,
        onError: _onInitializationFailed,
      ),
    );
  });

  void checkForUpdates({bool manual = true}) => handle(() => _startUpdateCheck(manual: manual));

  void resetManualUpdateCheckResult() => handle(() {
    setState(
      state.copyWith(
        operation: state.operation.copyWith(
          showManualCheckResult: false,
        ),
      ),
    );

    final bool shouldReturnToIdle =
        state.error != null || state.isUpToDate || state.loadingStage == AppUpdatingLoadingStage.checking;

    if (shouldReturnToIdle) {
      _returnToIdle();
    }
  });

  void updateApplication() => handle(_startAppUpdate);

  void cancelInstallerDownload() => handle(() {
    final bool canCancelDownload =
        state.loadingStage == AppUpdatingLoadingStage.downloading ||
        state.loadingStage == AppUpdatingLoadingStage.verifying;

    if (!canCancelDownload) {
      return;
    }

    final Completer<void>? downloadCancellation = state.operation.downloadCancellation;
    setState(
      state.copyWith(
        operation: state.operation.copyWith(
          attemptId: state.operation.attemptId + 1,
          downloadCancellation: const ValueData(null),
        ),
      ),
    );
    downloadCancellation?.complete();

    _returnToIdle();
  });

  void retryUpdate() => handle(() {
    final AppUpdateException? updateError = state.error;
    final bool needsUpdateCheck = updateError is AppUpdateCheckException || state.availableUpdate == null;

    if (needsUpdateCheck) {
      _startUpdateCheck(manual: true);
    } else {
      _startAppUpdate(
        forceDownload: updateError is AppUpdateDamagedException || updateError is AppUpdateDownloadException,
      );
    }
  });

  void removeUpdateNotification() => handle(
    () => setState(
      state.copyWith(
        updatedVersion: const ValueData(
          null,
        ),
      ),
    ),
  );

  void prepareForUpdateExit(
    String? serverId, {
    VoidCallback? onPrepared,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) => handle(
    () async {
      final String? operationId = state.operation.installationOperationId;
      final AvailableAppUpdate? availableUpdate = state.availableUpdate;
      final bool shouldSaveAttempt =
          operationId != null && availableUpdate != null && state.loadingStage == AppUpdatingLoadingStage.installing;

      if (shouldSaveAttempt) {
        await _repository.saveInstallationAttempt(
          AppUpdateInstallationAttempt(
            operationId: operationId,
            sourceVersion: state.version!,
            update: availableUpdate,
            restoreServerId: serverId,
          ),
        );
      }

      onPrepared?.call();
    },
    errorHandler: (error, stackTrace) {
      _logUpdateError(
        stage: 'prepare-exit',
        error: error,
        stackTrace: stackTrace,
      );
      onError?.call(error, stackTrace);
    },
  );

  Future<void> cancelUpdateExit() => handle(
    _repository.removeInstallationAttempt,
    errorHandler: (error, stackTrace) {
      _logUpdateError(
        stage: 'cancel-exit',
        error: error,
        stackTrace: stackTrace,
      );
    },
    completionHandler: () {
      if (state.loadingStage == AppUpdatingLoadingStage.installing) {
        _setUpdateError(
          attemptId: state.operation.attemptId,
          updateError: const AppUpdateInstallationException(),
          error: StateError('Installer shutdown cancelled'),
          stackTrace: StackTrace.current,
        );
      }
    },
  );

  @override
  void dispose() {
    state.operation.checkTimer?.cancel();
    state.operation.downloadCancellation?.complete();
    super.dispose();
  }

  Future<void> _onInstalledVersionLoaded(AppVersion installedVersion) => handle(
    () async {
      // Keep cache and installation metadata ordered with exit preparation.
      final AppVersionAndUpdatingState initializedState = await _initializeUpdating(installedVersion);

      setState(initializedState.copyWith(operation: state.operation));

      if (state.updatesSupported) {
        _startUpdateCheck(manual: false);
      }
    },
    errorHandler: _setInitializationError,
  );

  Future<void> _onInitializationFailed(Object error, StackTrace stackTrace) =>
      handle(() => _setInitializationError(error, stackTrace));

  void _setInitializationError(Object error, StackTrace stackTrace) {
    _logUpdateError(
      stage: 'initialize',
      error: error,
      stackTrace: stackTrace,
    );
    setState(AppVersionAndUpdatingState.idle(previousState: state));

    if (state.updatesSupported) {
      _startUpdateCheck(manual: false);
    }
  }

  Future<AppVersionAndUpdatingState> _initializeUpdating(AppVersion installedVersion) async {
    AppVersionAndUpdatingState initializedState = AppVersionAndUpdatingState.idle(
      previousState: state.copyWith(version: installedVersion),
    );

    if (!state.updatesSupported) {
      return initializedState;
    }

    final AvailableAppUpdate? cachedUpdate = await _readCachedUpdate(installedVersion);
    initializedState = initializedState.copyWith(availableUpdate: ValueData(cachedUpdate));

    return _restoreInstallationResult(initializedState, installedVersion);
  }

  Future<AvailableAppUpdate?> _readCachedUpdate(AppVersion installedVersion) async {
    try {
      await _repository.prepareInstallerCache(installedVersion);
      final DownloadedInstallerBundle? cachedBundle = await _repository.readInstallerBundle();

      return cachedBundle?.update;
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      _logUpdateError(
        stage: 'cache',
        error: error,
        stackTrace: stackTrace,
      );

      try {
        await _repository.removeInstallerBundle();
      } catch (error, stackTrace) {
        onError(error, stackTrace);
        _logUpdateError(
          stage: 'cache-cleanup',
          error: error,
          stackTrace: stackTrace,
        );
      }

      return null;
    }
  }

  Future<AppVersionAndUpdatingState> _restoreInstallationResult(
    AppVersionAndUpdatingState initializedState,
    AppVersion installedVersion,
  ) async {
    if (isDisposed) {
      return initializedState;
    }

    try {
      final AppUpdateInstallationAttempt? installationAttempt = await _repository.readInstallationAttempt();

      if (installationAttempt == null) {
        return initializedState;
      }

      AppVersionAndUpdatingState processedState = initializedState;
      final AppUpdateInstallationResult? installationResult = await _repository.readInstallationResult();
      final bool resultMatchesAttempt =
          installationResult != null &&
          installationResult.operationId == installationAttempt.operationId &&
          installationResult.version.compareTo(installationAttempt.update.version) == 0 &&
          installationResult.previousVersion.compareTo(installationAttempt.sourceVersion) == 0;

      if (resultMatchesAttempt) {
        final bool updateInstalled =
            installationResult.committed && installedVersion.compareTo(installationAttempt.update.version) == 0;
        final bool installationSucceeded =
            updateInstalled &&
            const ['success', 'launch_failed', 'autostart_failed'].contains(installationResult.status);
        final bool rollbackSucceeded =
            !installationResult.committed &&
            const ['rolled_back', 'rollback_launch_failed', 'failed'].contains(installationResult.status) &&
            installedVersion.compareTo(installationAttempt.sourceVersion) == 0;
        final bool installationFailed =
            !installationSucceeded &&
            (installedVersion.compareTo(installationAttempt.sourceVersion) == 0 ||
                installedVersion.compareTo(installationAttempt.update.version) == 0);

        if (installationSucceeded || installationFailed) {
          processedState = initializedState.copyWith(
            availableUpdate: ValueData(
              installationFailed && installationAttempt.update.version.compareTo(installedVersion) > 0
                  ? installationAttempt.update
                  : initializedState.availableUpdate,
            ),
            restoreServerId: updateInstalled || rollbackSucceeded ? installationAttempt.restoreServerId : null,
            updatedVersion: ValueData(installationSucceeded ? installedVersion.toString() : null),
          );

          if (installationFailed) {
            processedState = AppVersionAndUpdatingState.error(
              previousState: processedState,
              error: const AppUpdateInstallationException(),
            );
          }
        }

        logger.logInfo(
          'Update result: operation=${installationResult.operationId}, status=${installationResult.status}, '
          'committed=${installationResult.committed}, restart=${installationResult.restartRequired}, '
          'message=${installationResult.message}',
        );
      }

      await _repository.removeInstallationAttempt();

      return processedState;
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      _logUpdateError(
        stage: 'result',
        error: error,
        stackTrace: stackTrace,
      );

      try {
        await _repository.removeInstallationAttempt();
      } catch (error, stackTrace) {
        onError(error, stackTrace);
        _logUpdateError(
          stage: 'result-cleanup',
          error: error,
          stackTrace: stackTrace,
        );
      }

      return initializedState;
    }
  }

  void _startUpdateCheck({required bool manual}) {
    final bool canCheck =
        state.updatesSupported && state.initialLoadCompleted && state.version != null && !state.updating;

    if (!canCheck) {
      if (!manual) {
        _scheduleUpdateCheck();
      }

      return;
    }

    if (state.operation.checkingForUpdates) {
      if (manual) {
        setState(
          AppVersionAndUpdatingState.loading(
            previousState: state.copyWith(
              operation: state.operation.copyWith(
                showManualCheckResult: true,
              ),
            ),
            stage: AppUpdatingLoadingStage.checking,
          ),
        );
      } else {
        _scheduleUpdateCheck();
      }

      return;
    }

    setState(
      state.copyWith(
        operation: state.operation.copyWith(
          checkingForUpdates: true,
          showManualCheckResult: manual,
        ),
      ),
    );
    final int attemptId = state.operation.attemptId;

    if (manual) {
      setState(
        AppVersionAndUpdatingState.loading(
          previousState: state,
          stage: AppUpdatingLoadingStage.checking,
        ),
      );
    }

    unawaited(
      _repository
          .findAvailableUpdate(state.version!)
          .then(
            (availableUpdate) => _onUpdateCheckCompleted(
              availableUpdate: availableUpdate,
              attemptId: attemptId,
              manual: manual,
            ),
            onError: (Object error, StackTrace stackTrace) => _onUpdateCheckFailed(
              attemptId: attemptId,
              manual: manual,
              error: error,
              stackTrace: stackTrace,
            ),
          ),
    );
  }

  Future<void> _onUpdateCheckCompleted({
    required AvailableAppUpdate? availableUpdate,
    required int attemptId,
    required bool manual,
  }) => handle(
    () {
      final bool canReplaceUpdate = state.error == null || state.error is AppUpdateCheckException;
      final bool shouldApplyUpdate = !state.updating && attemptId == state.operation.attemptId && canReplaceUpdate;

      if (!shouldApplyUpdate) {
        return;
      }

      final bool showCheckResult = state.operation.showManualCheckResult;
      final AppVersionAndUpdatingState updatedState = state.copyWith(
        availableUpdate: ValueData(availableUpdate),
      );
      setState(
        showCheckResult
            ? AppVersionAndUpdatingState.idle(
                previousState: updatedState,
                isUpToDate: availableUpdate == null,
              )
            : updatedState,
      );
      final bool shouldReturnToIdle = !showCheckResult && state.error == null && !state.isUpToDate;

      if (shouldReturnToIdle) {
        _returnToIdle();
      }
    },
    completionHandler: () => _completeUpdateCheck(manual: manual),
  );

  Future<void> _onUpdateCheckFailed({
    required int attemptId,
    required bool manual,
    required Object error,
    required StackTrace stackTrace,
  }) => handle(
    () {
      _logUpdateError(
        stage: 'check',
        error: error,
        stackTrace: stackTrace,
      );
      final bool shouldShowError =
          state.operation.showManualCheckResult && !state.updating && attemptId == state.operation.attemptId;

      if (shouldShowError) {
        setState(
          AppVersionAndUpdatingState.error(previousState: state, error: const AppUpdateCheckException()),
        );
      }
    },
    completionHandler: () => _completeUpdateCheck(manual: manual),
  );

  void _completeUpdateCheck({required bool manual}) {
    setState(
      state.copyWith(
        operation: state.operation.copyWith(
          checkingForUpdates: false,
          showManualCheckResult: false,
        ),
      ),
    );

    if (!manual) {
      _scheduleUpdateCheck();
    }
  }

  void _scheduleUpdateCheck() {
    state.operation.checkTimer?.cancel();
    final Timer checkTimer = Timer(_checkInterval, () => checkForUpdates(manual: false));
    setState(state.copyWith(operation: state.operation.copyWith(checkTimer: checkTimer)));
  }

  void _startAppUpdate({bool forceDownload = false}) {
    final AvailableAppUpdate? availableUpdate = state.availableUpdate;
    final bool canUpdate =
        state.updatesSupported &&
        availableUpdate != null &&
        !state.updating &&
        state.loadingStage != AppUpdatingLoadingStage.checking;

    if (!canUpdate) {
      return;
    }

    final int attemptId = state.operation.attemptId + 1;
    setState(
      AppVersionAndUpdatingState.loading(
        previousState: state.copyWith(operation: state.operation.copyWith(attemptId: attemptId)),
        stage: AppUpdatingLoadingStage.verifying,
      ),
    );
    unawaited(
      _prepareInstallerBundle(availableUpdate, forceDownload: forceDownload).then(
        (installerBundle) => _onInstallerBundlePrepared(
          availableUpdate: availableUpdate,
          installerBundle: installerBundle,
          attemptId: attemptId,
        ),
        onError: (Object error, StackTrace stackTrace) => _onUpdateFailed(
          attemptId: attemptId,
          updateError: const AppUpdateInstallationException(),
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  }

  Future<void> _onInstallerBundlePrepared({
    required AvailableAppUpdate availableUpdate,
    required DownloadedInstallerBundle? installerBundle,
    required int attemptId,
  }) => handle(() {
    if (attemptId != state.operation.attemptId) {
      return;
    }

    if (installerBundle == null) {
      _startInstallerDownload(availableUpdate, attemptId);
    } else {
      _startInstallerLaunch(installerBundle, attemptId);
    }
  });

  Future<DownloadedInstallerBundle?> _prepareInstallerBundle(
    AvailableAppUpdate availableUpdate, {
    required bool forceDownload,
  }) async {
    if (forceDownload) {
      await _repository.removeInstallerBundle();

      return null;
    }

    final DownloadedInstallerBundle? cachedBundle = await _repository.readInstallerBundle();
    final bool matchesSelectedUpdate =
        cachedBundle != null && cachedBundle.update.hasSameInstallerBundle(availableUpdate);

    if (!matchesSelectedUpdate) {
      return null;
    }

    final bool bundleVerified = await _repository.verifyInstallerBundle(cachedBundle);

    if (bundleVerified) {
      return cachedBundle;
    }

    await _repository.removeInstallerBundle();

    return null;
  }

  void _startInstallerDownload(AvailableAppUpdate availableUpdate, int attemptId) {
    final Completer<void> downloadCancellation = Completer<void>();

    setState(
      AppVersionAndUpdatingState.loading(
        previousState: state.copyWith(
          operation: state.operation.copyWith(downloadCancellation: ValueData(downloadCancellation)),
        ),
        stage: AppUpdatingLoadingStage.downloading,
      ),
    );

    unawaited(
      _repository
          .downloadInstallerBundle(
            update: availableUpdate,
            cancellation: downloadCancellation.future,
            isCancelled: () => attemptId != state.operation.attemptId,
            onProgress: (progress) => _onDownloadProgress(attemptId, progress),
            attemptId: attemptId,
            onVerifying: () => _onBundleVerificationStarted(attemptId),
          )
          .then(
            (installerBundle) => _onInstallerBundleDownloaded(installerBundle, attemptId),
            onError: (Object error, StackTrace stackTrace) => _onUpdateFailed(
              attemptId: attemptId,
              updateError: error is DamagedInstallerBundleException
                  ? const AppUpdateDamagedException()
                  : const AppUpdateDownloadException(),
              error: error,
              stackTrace: stackTrace,
            ),
          ),
    );
  }

  Future<void> _onInstallerBundleDownloaded(
    DownloadedInstallerBundle installerBundle,
    int attemptId,
  ) => handle(() {
    if (attemptId != state.operation.attemptId) {
      return;
    }

    setState(
      AppVersionAndUpdatingState.loading(
        previousState: state.copyWith(
          operation: state.operation.copyWith(downloadCancellation: const ValueData(null)),
        ),
        stage: AppUpdatingLoadingStage.verifying,
      ),
    );
    _startInstallerLaunch(installerBundle, attemptId);
  });

  void _onBundleVerificationStarted(int attemptId) => handle(() {
    final bool isCurrentDownload =
        attemptId == state.operation.attemptId && state.loadingStage == AppUpdatingLoadingStage.downloading;

    if (isCurrentDownload) {
      setState(
        AppVersionAndUpdatingState.loading(
          previousState: state,
          stage: AppUpdatingLoadingStage.verifying,
          progress: 0.95,
        ),
      );
    }
  });

  void _onDownloadProgress(int attemptId, double progress) => handle(() {
    final bool isCurrentDownload =
        attemptId == state.operation.attemptId && state.loadingStage == AppUpdatingLoadingStage.downloading;

    if (isCurrentDownload) {
      setState(state.copyWith(progress: progress * 0.9));
    }
  });

  void _startInstallerLaunch(DownloadedInstallerBundle installerBundle, int attemptId) {
    setState(
      AppVersionAndUpdatingState.loading(
        previousState: state,
        stage: AppUpdatingLoadingStage.installing,
        progress: 1,
      ),
    );
    unawaited(
      Future<String>.sync(_repository.createInstallationOperationId).then(
        (operationId) => _onInstallationOperationCreated(
          installerBundle: installerBundle,
          attemptId: attemptId,
          operationId: operationId,
        ),
        onError: (Object error, StackTrace stackTrace) => _onInstallerLaunchFailed(
          attemptId: attemptId,
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  }

  Future<void> _onInstallationOperationCreated({
    required DownloadedInstallerBundle installerBundle,
    required int attemptId,
    required String operationId,
  }) => handle(() {
    if (attemptId != state.operation.attemptId) {
      return;
    }

    setState(state.copyWith(operation: state.operation.copyWith(installationOperationId: operationId)));

    // Setup requests exit through this controller. Do not keep its queue waiting for setup.
    unawaited(
      Future<void>.sync(() => _repository.launchInstaller(installerBundle, operationId)).then(
        (_) {},
        onError: (Object error, StackTrace stackTrace) => _onInstallerLaunchFailed(
          attemptId: attemptId,
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  });

  Future<void> _onInstallerLaunchFailed({
    required int attemptId,
    required Object error,
    required StackTrace stackTrace,
  }) => _onUpdateFailed(
    attemptId: attemptId,
    updateError: _mapInstallerLaunchError(error),
    error: error,
    stackTrace: stackTrace,
  );

  AppUpdateException _mapInstallerLaunchError(Object error) => switch (error) {
    PlatformException(code: 'permission-denied') => const AppUpdatePermissionException(),
    PlatformException(code: 'damaged-file') => const AppUpdateDamagedException(),
    _ => const AppUpdateInstallationException(),
  };

  Future<void> _onUpdateFailed({
    required int attemptId,
    required AppUpdateException updateError,
    required Object error,
    required StackTrace stackTrace,
  }) => handle(
    () => _setUpdateError(
      attemptId: attemptId,
      updateError: updateError,
      error: error,
      stackTrace: stackTrace,
    ),
  );

  void _setUpdateError({
    required int attemptId,
    required AppUpdateException updateError,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final bool shouldIgnoreFailure =
        attemptId != state.operation.attemptId || error is InstallerBundleDownloadCancelledException;

    if (shouldIgnoreFailure) {
      return;
    }

    _logUpdateError(
      stage: updateError.runtimeType.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    setState(
      AppVersionAndUpdatingState.error(
        previousState: state.copyWith(
          operation: state.operation.copyWith(
            downloadCancellation: const ValueData(
              null,
            ),
          ),
        ),
        error: updateError,
      ),
    );
  }

  void _returnToIdle() => setState(
    AppVersionAndUpdatingState.idle(
      previousState: state,
    ),
  );

  void _logUpdateError({
    required String stage,
    required Object error,
    required StackTrace stackTrace,
  }) => logger.logError(
    'Update stage=$stage operation=${state.operation.installationOperationId} version=${state.availableUpdate?.version}',
    error: error,
    stackTrace: stackTrace,
  );
}
