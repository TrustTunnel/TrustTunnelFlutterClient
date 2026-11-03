import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/common/utils/cancellable_stream_reader.dart';
import 'package:trusttunnel/data/model/app_update_failure.dart';
import 'package:trusttunnel/data/repository/app_updating_repository.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/controller/app_updating_state.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_attempt.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_result.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_update_installation_status.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/downloaded_installer_bundle.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/installer_bundle_preparation_status.dart';

final class AppUpdatingController extends BaseStateController<AppUpdatingState> with SequentialControllerHandler {
  final AppUpdatingRepository _appUpdatingRepository;

  AppUpdatingController({
    required this._appUpdatingRepository,
    required bool updatesSupported,
  }) : assert(
         !updatesSupported || defaultTargetPlatform == TargetPlatform.windows,
         'App updates are currently supported only on Windows',
       ),
       super(
         initialState: AppUpdatingState.initial(
           updatesSupported: updatesSupported,
         ),
       );

  CancellableStreamReader<InstallerBundlePreparationStatus>? _preparation;

  void loadSavedUpdateData(
    AppVersion installedVersion, {
    VoidCallback? onCompleted,
  }) => handle(
    () async {
      // Keep cache and installation metadata ordered with exit preparation.
      final AppUpdatingState savedUpdateState = await _restoreSavedUpdateState(installedVersion);

      setState(savedUpdateState);
    },
    errorHandler: _onSavedUpdateDataLoadFailed,
    completionHandler: () => onCompleted?.call(),
  );

  void updateApplication({
    required AvailableAppUpdate update,
    bool forceDownload = false,
  }) => handle(
    () => _startAppUpdate(
      update: update,
      forceDownload: forceDownload,
    ),
  );

  void resetError() => handle(() {
    if (state.error != null) {
      _returnToIdle();
    }
  });

  void cancelInstallerDownload() => handle(() {
    if (!state.canCancelDownload) {
      return;
    }

    final CancellableStreamReader<InstallerBundlePreparationStatus>? preparation = _preparation;
    _preparation = null;
    setState(
      AppUpdatingState.idle(
        previousState: state.copyWith(operationRevision: state.operationRevision + 1),
      ),
    );

    if (preparation != null) {
      unawaited(_cancelInstallerPreparation(preparation));
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
      final String? operationId = state.installationOperationId;
      final AvailableAppUpdate? update = state.update;
      final bool shouldSaveAttempt =
          operationId != null && update != null && state.loadingStage == AppUpdatingLoadingStage.installing;

      if (shouldSaveAttempt) {
        await _appUpdatingRepository.saveInstallationAttempt(
          AppUpdateInstallationAttempt(
            operationId: operationId,
            sourceVersion: state.version!,
            update: update,
            restoreServerId: serverId,
          ),
        );
      }

      onPrepared?.call();
    },
    errorHandler: onError,
  );

  void cancelUpdateExit({VoidCallback? onCompleted}) => unawaited(
    handle(
      _appUpdatingRepository.removeInstallationAttempt,
      completionHandler: () {
        if (state.loadingStage == AppUpdatingLoadingStage.installing) {
          _setUpdateError(
            operationRevision: state.operationRevision,
            updateError: const AppUpdateInstallationException(),
            error: StateError('Installer shutdown cancelled'),
            stackTrace: StackTrace.current,
          );
        }

        onCompleted?.call();
      },
    ),
  );

  @override
  void dispose() {
    final CancellableStreamReader<InstallerBundlePreparationStatus>? preparation = _preparation;
    _preparation = null;

    if (preparation != null) {
      unawaited(_cancelInstallerPreparation(preparation));
    }

    super.dispose();
  }

  void _onSavedUpdateDataLoadFailed(Object error, StackTrace stackTrace) => _returnToIdle();

  Future<AppUpdatingState> _restoreSavedUpdateState(AppVersion installedVersion) async {
    AppUpdatingState savedUpdateState = AppUpdatingState.idle(
      previousState: state.copyWith(version: installedVersion),
    );

    if (!state.updatesSupported) {
      return savedUpdateState;
    }

    final AvailableAppUpdate? cachedUpdate = await _readCachedUpdate(installedVersion);
    savedUpdateState = savedUpdateState.copyWith(update: ValueData(cachedUpdate));

    return _restoreInstallationResult(savedUpdateState, installedVersion);
  }

  Future<AvailableAppUpdate?> _readCachedUpdate(AppVersion installedVersion) async {
    try {
      await _appUpdatingRepository.prepareInstallerCache(installedVersion);
      final DownloadedInstallerBundle? cachedBundle = await _appUpdatingRepository.readInstallerBundle();

      return cachedBundle?.update;
    } catch (error, stackTrace) {
      onError(error, stackTrace);

      try {
        await _appUpdatingRepository.removeInstallerBundle();
      } catch (error, stackTrace) {
        onError(error, stackTrace);
      }

      return null;
    }
  }

  Future<AppUpdatingState> _restoreInstallationResult(
    AppUpdatingState savedUpdateState,
    AppVersion installedVersion,
  ) async {
    if (isDisposed) {
      return savedUpdateState;
    }

    try {
      final AppUpdateInstallationAttempt? installationAttempt = await _appUpdatingRepository.readInstallationAttempt();

      if (installationAttempt == null) {
        return savedUpdateState;
      }

      AppUpdatingState processedState = savedUpdateState;
      final AppUpdateInstallationResult? installationResult = await _appUpdatingRepository.readInstallationResult();
      final bool resultMatchesAttempt =
          installationResult != null &&
          installationResult.operationId == installationAttempt.operationId &&
          installationResult.version.compareTo(installationAttempt.update.version) == 0 &&
          installationResult.previousVersion.compareTo(installationAttempt.sourceVersion) == 0;

      if (resultMatchesAttempt) {
        final bool updateInstalled =
            installationResult.installationApplied &&
            installedVersion.compareTo(installationAttempt.update.version) == 0;
        final bool installationSucceeded =
            updateInstalled &&
            const [
              AppUpdateInstallationStatus.success,
              AppUpdateInstallationStatus.launchFailed,
              AppUpdateInstallationStatus.autostartFailed,
            ].contains(installationResult.status);
        final bool rollbackSucceeded =
            !installationResult.installationApplied &&
            const [
              AppUpdateInstallationStatus.rolledBack,
              AppUpdateInstallationStatus.rollbackLaunchFailed,
              AppUpdateInstallationStatus.failed,
            ].contains(installationResult.status) &&
            installedVersion.compareTo(installationAttempt.sourceVersion) == 0;
        final bool installationFailed =
            !installationSucceeded &&
            (installedVersion.compareTo(installationAttempt.sourceVersion) == 0 ||
                installedVersion.compareTo(installationAttempt.update.version) == 0);

        if (installationSucceeded || installationFailed) {
          processedState = savedUpdateState.copyWith(
            update: ValueData(
              installationFailed && installationAttempt.update.version.compareTo(installedVersion) > 0
                  ? installationAttempt.update
                  : savedUpdateState.update,
            ),
            restoreServerId: updateInstalled || rollbackSucceeded ? installationAttempt.restoreServerId : null,
            updatedVersion: ValueData(installationSucceeded ? installedVersion.toString() : null),
          );

          if (installationFailed) {
            processedState = AppUpdatingState.error(
              previousState: processedState,
              error: const AppUpdateInstallationException(),
            );
          }
        }
      }

      await _appUpdatingRepository.removeInstallationAttempt();

      return processedState;
    } catch (error, stackTrace) {
      onError(error, stackTrace);

      try {
        await _appUpdatingRepository.removeInstallationAttempt();
      } catch (error, stackTrace) {
        onError(error, stackTrace);
      }

      return savedUpdateState;
    }
  }

  void _startAppUpdate({
    required AvailableAppUpdate update,
    required bool forceDownload,
  }) {
    if (!state.updatesSupported || state.updating) {
      return;
    }

    final int operationRevision = state.operationRevision + 1;
    setState(
      AppUpdatingState.loading(
        previousState: state.copyWith(update: ValueData(update), operationRevision: operationRevision),
        stage: AppUpdatingLoadingStage.verifying,
      ),
    );
    final CancellableStreamReader<InstallerBundlePreparationStatus> preparation = CancellableStreamReader(
      _appUpdatingRepository.prepareInstallerBundle(update: update, forceDownload: forceDownload),
    );
    _preparation = preparation;

    // Keep the command queue free for cancellation and installer shutdown requests.
    unawaited(_readInstallerPreparation(preparation, operationRevision));
  }

  Future<void> _readInstallerPreparation(
    CancellableStreamReader<InstallerBundlePreparationStatus> preparation,
    int operationRevision,
  ) async {
    bool ready = false;

    try {
      await for (final InstallerBundlePreparationStatus status in preparation.stream) {
        await _onInstallerPreparationStatus(status, operationRevision);
        ready = ready || status is InstallerBundleReadyStatus;
      }

      if (!ready) {
        await _onUpdateFailed(
          operationRevision: operationRevision,
          updateError: const AppUpdateDownloadException(),
          error: StateError('Installer preparation ended without a bundle'),
          stackTrace: StackTrace.current,
        );
      }
    } catch (error, stackTrace) {
      await _onUpdateFailed(
        operationRevision: operationRevision,
        updateError: const AppUpdateDownloadException(),
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (identical(_preparation, preparation)) {
        _preparation = null;
      }
    }
  }

  Future<void> _onInstallerPreparationStatus(
    InstallerBundlePreparationStatus status,
    int operationRevision,
  ) => handle(() {
    if (operationRevision != state.operationRevision) {
      return;
    }

    switch (status) {
      case InstallerBundlePreparingStatus():
        setState(AppUpdatingState.loading(previousState: state, stage: AppUpdatingLoadingStage.verifying));
      case InstallerBundleDownloadingStatus(:final receivedBytes, :final totalBytes):
        setState(
          AppUpdatingState.loading(
            previousState: state,
            stage: AppUpdatingLoadingStage.downloading,
            progress: (receivedBytes / totalBytes).clamp(0.0, 1.0) * 0.9,
          ),
        );
      case InstallerBundleVerifyingStatus():
        setState(
          AppUpdatingState.loading(
            previousState: state,
            stage: AppUpdatingLoadingStage.verifying,
            progress: 0.95,
          ),
        );
      case InstallerBundleReadyStatus(:final bundle):
        _preparation = null;
        _startInstallerLaunch(bundle, operationRevision);
    }
  });

  Future<void> _cancelInstallerPreparation(
    CancellableStreamReader<InstallerBundlePreparationStatus> preparation,
  ) async {
    try {
      await preparation.cancel();
    } catch (error, stackTrace) {
      _logUpdateError(
        stage: 'cancel-preparation',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _startInstallerLaunch(DownloadedInstallerBundle installerBundle, int operationRevision) {
    setState(
      AppUpdatingState.loading(
        previousState: state,
        stage: AppUpdatingLoadingStage.installing,
        progress: 1,
      ),
    );
    unawaited(
      Future<String>.sync(_appUpdatingRepository.createInstallationOperationId).then(
        (operationId) => _onInstallationOperationCreated(
          installerBundle: installerBundle,
          operationRevision: operationRevision,
          operationId: operationId,
        ),
        onError: (Object error, StackTrace stackTrace) => _onInstallerLaunchFailed(
          operationRevision: operationRevision,
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  }

  Future<void> _onInstallationOperationCreated({
    required DownloadedInstallerBundle installerBundle,
    required int operationRevision,
    required String operationId,
  }) => handle(() {
    if (operationRevision != state.operationRevision) {
      return;
    }

    setState(state.copyWith(installationOperationId: ValueData(operationId)));

    // Setup requests exit through this controller. Do not keep its queue waiting for setup.
    unawaited(
      Future<void>.sync(() => _appUpdatingRepository.launchInstaller(installerBundle, operationId)).then(
        (_) {},
        onError: (Object error, StackTrace stackTrace) => _onInstallerLaunchFailed(
          operationRevision: operationRevision,
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  });

  Future<void> _onInstallerLaunchFailed({
    required int operationRevision,
    required Object error,
    required StackTrace stackTrace,
  }) => _onUpdateFailed(
    operationRevision: operationRevision,
    updateError: const AppUpdateInstallationException(),
    error: error,
    stackTrace: stackTrace,
  );

  Future<void> _onUpdateFailed({
    required int operationRevision,
    required AppUpdateException updateError,
    required Object error,
    required StackTrace stackTrace,
  }) => handle(
    () => _setUpdateError(
      operationRevision: operationRevision,
      updateError: updateError,
      error: error,
      stackTrace: stackTrace,
    ),
  );

  void _setUpdateError({
    required int operationRevision,
    required AppUpdateException updateError,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final bool shouldIgnoreFailure = operationRevision != state.operationRevision || error is AppUpdateCancelledFailure;

    if (shouldIgnoreFailure) {
      return;
    }

    final AppUpdateException presentationError = error is AppUpdateFailure
        ? AppUpdateException.fromFailure(error)
        : updateError;
    _logUpdateError(
      stage: presentationError.runtimeType.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    _preparation = null;
    setState(
      AppUpdatingState.error(
        previousState: state,
        error: presentationError,
      ),
    );
  }

  void _returnToIdle() => setState(
    AppUpdatingState.idle(
      previousState: state,
    ),
  );

  void _logUpdateError({
    required String stage,
    required Object error,
    required StackTrace stackTrace,
  }) => logger.logError(
    'Update stage=$stage operation=${state.installationOperationId} version=${state.update?.version}',
    error: error,
    stackTrace: stackTrace,
  );
}
