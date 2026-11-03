import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/constants/app_update_constants.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/feature/app/controller/windows_app_window_controller.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/controller/app_update_check_controller.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/controller/app_updating_controller.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_exit_mode.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_controller.dart';

class AppVersionAndUpdatingScope extends StatefulWidget {
  final Widget child;

  const AppVersionAndUpdatingScope({
    required this.child,
    super.key,
  });

  static AppVersionAndUpdatingScopeController controllerOf({
    required BuildContext context,
    bool listen = true,
    AppVersionAndUpdatingScopeAspect? aspect,
  }) =>
      (listen
              ? InheritedModel.inheritFrom<_InheritedAppUpdatingScope>(context, aspect: aspect)!
              : context.getInheritedWidgetOfExactType<_InheritedAppUpdatingScope>()!)
          .controller;

  @override
  State<AppVersionAndUpdatingScope> createState() => _AppVersionAndUpdatingScopeState();
}

class _AppVersionAndUpdatingScopeState extends State<AppVersionAndUpdatingScope>
    implements AppVersionAndUpdatingScopeController {
  late final AppUpdateCheckController _checkController;
  late final AppUpdatingController _updatingController;
  late final Listenable _controllersChanges;
  WindowsAppWindowController? _appWindowController;

  @override
  bool get updatesSupported => _updatingController.state.updatesSupported;

  @override
  AppVersion? get version => _checkController.state.version;

  @override
  AvailableAppUpdate? get availableUpdate =>
      _updatingController.state.updating || _updatingController.state.error != null
      ? _updatingController.state.update
      : _checkController.state.availableUpdate;

  @override
  bool get initialLoadCompleted => _checkController.state.initialLoadCompleted;

  @override
  bool get checkingForUpdates => _checkController.state.manualCheckInProgress && !updating;

  @override
  bool get updating => _updatingController.state.updating;

  @override
  bool get canCancelDownload => _updatingController.state.canCancelDownload;

  @override
  bool get isUpToDate => _checkController.state.isUpToDate && !updating && !checkingForUpdates && error == null;

  @override
  double get progress => _updatingController.state.progress;

  @override
  AppUpdateException? get error =>
      updating || checkingForUpdates ? null : _updatingController.state.error ?? _checkController.state.error;

  @override
  bool get showUpdateIndicator => availableUpdate != null || (error != null && error is! AppUpdateCheckException);

  @override
  String? get restoreServerId => _updatingController.state.restoreServerId;

  @override
  String? get updatedVersion => _updatingController.state.updatedVersion;

  @override
  void initState() {
    super.initState();
    final appUpdatingRepository = context.repositoryFactory.appUpdatingRepository;

    _updatingController = AppUpdatingController(
      appUpdatingRepository: appUpdatingRepository,
      updatesSupported: defaultTargetPlatform == TargetPlatform.windows,
    );
    _checkController = AppUpdateCheckController(
      appUpdatingRepository: appUpdatingRepository,
      checkInterval: AppUpdateConstants.checkInterval,
      updatesSupported: updatesSupported,
      loadSavedUpdateData: (version) async {
        final Completer<void> savedUpdateDataLoadCompleter = Completer<void>();
        _updatingController.loadSavedUpdateData(version, onCompleted: savedUpdateDataLoadCompleter.complete);
        await savedUpdateDataLoadCompleter.future;

        return _updatingController.state.update;
      },
      canCheck: () => !_updatingController.state.updating,
      canApplyResult: (operationRevision) =>
          operationRevision == _updatingController.state.operationRevision &&
          !_updatingController.state.updating &&
          _updatingController.state.error == null,
      updateOperationRevision: () => _updatingController.state.operationRevision,
    );

    _controllersChanges = Listenable.merge([
      _checkController,
      _updatingController,
    ]);

    if (updatesSupported) {
      prepareUpdateLogicInWindowController();
    }

    _checkController.loadInitialDataAndStartUpdateChecks();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controllersChanges,
    builder: (context, child) => _InheritedAppUpdatingScope(
      controller: this,
      updatesSupported: updatesSupported,
      version: version,
      availableUpdate: availableUpdate,
      initialLoadCompleted: initialLoadCompleted,
      checkingForUpdates: checkingForUpdates,
      updating: updating,
      canCancelDownload: canCancelDownload,
      isUpToDate: isUpToDate,
      progress: progress,
      error: error,
      showUpdateIndicator: showUpdateIndicator,
      restoreServerId: restoreServerId,
      updatedVersion: updatedVersion,
      child: child!,
    ),
    child: widget.child,
  );

  @override
  void addListener(VoidCallback listener) => _controllersChanges.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _controllersChanges.removeListener(listener);

  @override
  void checkForUpdates({bool manual = true}) => _checkController.checkForUpdates(
    manual: manual,
    onBeforeManualCheck: _updatingController.resetError,
  );

  @override
  void updateApplication() => _startAppUpdate();

  @override
  void retryUpdate() {
    final AppUpdateException? updateError = error;

    if (updateError is AppUpdateCheckException || availableUpdate == null) {
      checkForUpdates();
    } else {
      _startAppUpdate(
        forceDownload: updateError is AppUpdateDamagedException || updateError is AppUpdateDownloadException,
      );
    }
  }

  @override
  void cancelInstallerDownload() => _updatingController.cancelInstallerDownload();

  @override
  void resetManualUpdateCheckResult() {
    _checkController.resetManualUpdateCheckResult();
    _updatingController.resetError();
  }

  @override
  void removeUpdateNotification() => _updatingController.removeUpdateNotification();

  void prepareUpdateLogicInWindowController() {
    final WindowsAppWindowController appWindowController =
        context.dependencyFactory.appWindowController as WindowsAppWindowController;
    _appWindowController = appWindowController;

    appWindowController.onPrepareUpdateExit = () async {
      final VpnScopeController vpn = VpnScope.vpnControllerOf(context, listen: false);

      try {
        final Completer<String?> vpnExitPreparationCompleter = Completer<String?>();
        vpn.stopForExit(
          mode: VpnExitMode.installation,
          onPrepared: vpnExitPreparationCompleter.complete,
          onError: vpnExitPreparationCompleter.completeError,
        );
        final String? serverId = await vpnExitPreparationCompleter.future;

        final Completer<void> updateExitPreparationCompleter = Completer<void>();
        _updatingController.prepareForUpdateExit(
          serverId,
          onPrepared: updateExitPreparationCompleter.complete,
          onError: updateExitPreparationCompleter.completeError,
        );
        await updateExitPreparationCompleter.future;
      } catch (_) {
        vpn.cancelExit(mode: VpnExitMode.installation);

        rethrow;
      }
    };
    _appWindowController?.onCancelUpdateExit = () async {
      VpnScope.vpnControllerOf(context, listen: false).cancelExit(mode: VpnExitMode.installation);
      final Completer<void> updateExitCancellationCompleter = Completer<void>();
      _updatingController.cancelUpdateExit(onCompleted: updateExitCancellationCompleter.complete);
      await updateExitCancellationCompleter.future;
    };
  }

  void _startAppUpdate({bool forceDownload = false}) {
    final AvailableAppUpdate? update = availableUpdate;

    if (!updatesSupported || update == null || updating || checkingForUpdates) {
      return;
    }

    _checkController.resetManualUpdateCheckResult();
    _updatingController.updateApplication(update: update, forceDownload: forceDownload);
  }

  @override
  void dispose() {
    _appWindowController?.onPrepareUpdateExit = null;
    _appWindowController?.onCancelUpdateExit = null;
    _checkController.dispose();
    _updatingController.dispose();
    super.dispose();
  }
}

class _InheritedAppUpdatingScope extends InheritedModel<AppVersionAndUpdatingScopeAspect> {
  final AppVersionAndUpdatingScopeController controller;
  final bool updatesSupported;
  final AppVersion? version;
  final AvailableAppUpdate? availableUpdate;
  final bool initialLoadCompleted;
  final bool checkingForUpdates;
  final bool updating;
  final bool canCancelDownload;
  final bool isUpToDate;
  final double progress;
  final AppUpdateException? error;
  final bool showUpdateIndicator;
  final String? restoreServerId;
  final String? updatedVersion;

  const _InheritedAppUpdatingScope({
    required this.controller,
    required this.updatesSupported,
    required this.version,
    required this.availableUpdate,
    required this.initialLoadCompleted,
    required this.checkingForUpdates,
    required this.updating,
    required this.canCancelDownload,
    required this.isUpToDate,
    required this.progress,
    required this.error,
    required this.showUpdateIndicator,
    required this.restoreServerId,
    required this.updatedVersion,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedAppUpdatingScope oldWidget) =>
      updatesSupported != oldWidget.updatesSupported ||
      version != oldWidget.version ||
      availableUpdate != oldWidget.availableUpdate ||
      initialLoadCompleted != oldWidget.initialLoadCompleted ||
      checkingForUpdates != oldWidget.checkingForUpdates ||
      updating != oldWidget.updating ||
      canCancelDownload != oldWidget.canCancelDownload ||
      isUpToDate != oldWidget.isUpToDate ||
      progress != oldWidget.progress ||
      error != oldWidget.error ||
      showUpdateIndicator != oldWidget.showUpdateIndicator ||
      restoreServerId != oldWidget.restoreServerId ||
      updatedVersion != oldWidget.updatedVersion;

  @override
  bool updateShouldNotifyDependent(
    _InheritedAppUpdatingScope oldWidget,
    Set<AppVersionAndUpdatingScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) {
      return updateShouldNotify(oldWidget);
    }

    return dependencies.any(
      (aspect) => switch (aspect) {
        AppVersionAndUpdatingScopeAspect.progress =>
          progress != oldWidget.progress ||
              updating != oldWidget.updating ||
              canCancelDownload != oldWidget.canCancelDownload ||
              availableUpdate != oldWidget.availableUpdate,
        AppVersionAndUpdatingScopeAspect.status =>
          updatesSupported != oldWidget.updatesSupported ||
              version != oldWidget.version ||
              availableUpdate != oldWidget.availableUpdate ||
              initialLoadCompleted != oldWidget.initialLoadCompleted ||
              checkingForUpdates != oldWidget.checkingForUpdates ||
              updating != oldWidget.updating ||
              canCancelDownload != oldWidget.canCancelDownload ||
              isUpToDate != oldWidget.isUpToDate ||
              error != oldWidget.error ||
              showUpdateIndicator != oldWidget.showUpdateIndicator ||
              restoreServerId != oldWidget.restoreServerId ||
              updatedVersion != oldWidget.updatedVersion,
      },
    );
  }
}
