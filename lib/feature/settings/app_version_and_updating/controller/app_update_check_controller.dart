import 'dart:async';

import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/repository/app_updating_repository.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/controller/app_update_check_state.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

/// Loads the installed version and manages manual and background release checks.
final class AppUpdateCheckController extends BaseStateController<AppUpdateCheckState> with SequentialControllerHandler {
  final AppUpdatingRepository _appUpdatingRepository;
  final Duration _checkInterval;
  final bool _updatesSupported;
  final Future<AvailableAppUpdate?> Function(AppVersion version) _loadSavedUpdateData;
  final bool Function() _canCheck;
  final bool Function(int operationRevision) _canApplyResult;
  final int Function() _updateOperationRevision;

  AppUpdateCheckController({
    required this._appUpdatingRepository,
    required this._checkInterval,
    required this._updatesSupported,
    required this._loadSavedUpdateData,
    required this._canCheck,
    required this._canApplyResult,
    required this._updateOperationRevision,
  }) : super(
         initialState: const AppUpdateCheckState(),
       );

  Timer? _checkTimer;

  void loadInitialDataAndStartUpdateChecks() => handle(
    _loadInitialData,
    errorHandler: (error, stackTrace) => setState(state.copyWith(initialLoadCompleted: true)),
    completionHandler: () {
      if (_updatesSupported) {
        _startUpdateCheck(manual: false);
      }
    },
  );

  void checkForUpdates({
    bool manual = true,
    void Function()? onBeforeManualCheck,
  }) => handle(() {
    if (manual && onBeforeManualCheck != null && _canStartUpdateCheck()) {
      onBeforeManualCheck();
    }

    _startUpdateCheck(manual: manual);
  });

  void resetManualUpdateCheckResult() => handle(
    () => setState(
      state.copyWith(
        showManualCheckResult: false,
        isUpToDate: false,
        error: const ValueData(null),
      ),
    ),
  );

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final AppVersion version = await _appUpdatingRepository.installedVersion;

    // Restore the cache and installation result before the first release check.
    final AvailableAppUpdate? cachedUpdate = await _loadSavedUpdateData(version);

    setState(
      state.copyWith(
        version: version,
        initialLoadCompleted: true,
        availableUpdate: ValueData(cachedUpdate),
      ),
    );
  }

  bool _canStartUpdateCheck() =>
      _updatesSupported && state.initialLoadCompleted && state.version != null && _canCheck();

  void _startUpdateCheck({required bool manual}) {
    if (!_canStartUpdateCheck()) {
      if (!manual) {
        _scheduleUpdateCheck();
      }

      return;
    }

    if (state.checkingForUpdates) {
      if (manual) {
        setState(
          state.copyWith(
            showManualCheckResult: true,
            isUpToDate: false,
            error: const ValueData(null),
          ),
        );
      } else {
        _scheduleUpdateCheck();
      }

      return;
    }

    setState(
      state.copyWith(
        checkingForUpdates: true,
        showManualCheckResult: manual,
        isUpToDate: manual ? false : state.isUpToDate,
        error: manual ? const ValueData(null) : null,
      ),
    );

    final int operationRevision = _updateOperationRevision();
    unawaited(
      _appUpdatingRepository
          .findAvailableUpdate(state.version!)
          .then(
            (update) => _onUpdateCheckCompleted(
              update: update,
              operationRevision: operationRevision,
              manual: manual,
            ),
            onError: (Object error, StackTrace stackTrace) => _onUpdateCheckFailed(
              operationRevision: operationRevision,
              manual: manual,
              error: error,
              stackTrace: stackTrace,
            ),
          ),
    );
  }

  Future<void> _onUpdateCheckCompleted({
    required AvailableAppUpdate? update,
    required int operationRevision,
    required bool manual,
  }) => handle(
    () {
      if (!_canApplyResult(operationRevision)) {
        return;
      }

      final bool showResult = state.showManualCheckResult;
      setState(
        state.copyWith(
          availableUpdate: ValueData(update),
          isUpToDate: showResult ? update == null : state.isUpToDate && update == null,
          error: showResult ? const ValueData(null) : null,
        ),
      );
    },
    completionHandler: () => _completeUpdateCheck(manual: manual),
  );

  Future<void> _onUpdateCheckFailed({
    required int operationRevision,
    required bool manual,
    required Object error,
    required StackTrace stackTrace,
  }) => handle(
    () => Error.throwWithStackTrace(error, stackTrace),
    errorHandler: (error, stackTrace) {
      if (state.showManualCheckResult && _canApplyResult(operationRevision)) {
        setState(state.copyWith(error: const ValueData(AppUpdateCheckException()), isUpToDate: false));
      }
    },
    completionHandler: () => _completeUpdateCheck(manual: manual),
  );

  void _completeUpdateCheck({required bool manual}) {
    setState(state.copyWith(checkingForUpdates: false, showManualCheckResult: false));

    if (!manual) {
      _scheduleUpdateCheck();
    }
  }

  void _scheduleUpdateCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer(_checkInterval, () => checkForUpdates(manual: false));
  }
}
