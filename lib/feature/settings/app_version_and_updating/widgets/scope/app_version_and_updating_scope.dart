import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/constants/app_update_constants.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/feature/app/controller/windows_app_window_controller.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/controller/app_version_and_updating_controller.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/controller/app_version_and_updating_state.dart';
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
  late final AppVersionAndUpdatingController _controller;
  WindowsAppWindowController? _window;

  @override
  bool get updatesSupported => _controller.state.updatesSupported;

  @override
  AppVersion? get version => _controller.state.version;

  @override
  AvailableAppUpdate? get availableUpdate => _controller.state.availableUpdate;

  @override
  bool get initialLoadCompleted => _controller.state.initialLoadCompleted;

  @override
  bool get checkingForUpdates => _controller.state.loadingStage == AppUpdatingLoadingStage.checking;

  @override
  bool get updating => _controller.state.updating;

  @override
  bool get canCancelDownload =>
      _controller.state.loadingStage == AppUpdatingLoadingStage.downloading ||
      _controller.state.loadingStage == AppUpdatingLoadingStage.verifying;

  @override
  bool get isUpToDate => _controller.state.isUpToDate;

  @override
  double get progress => _controller.state.progress;

  @override
  AppUpdateException? get error => _controller.state.error;

  @override
  bool get showUpdateIndicator => _controller.state.showUpdateIndicator;

  @override
  String? get restoreServerId => _controller.state.restoreServerId;

  @override
  String? get updatedVersion => _controller.state.updatedVersion;

  @override
  void initState() {
    super.initState();
    _controller = AppVersionAndUpdatingController(
      repository: context.repositoryFactory.appUpdatingRepository,
      checkInterval: AppUpdateConstants.checkInterval,
      updatesSupported: defaultTargetPlatform == TargetPlatform.windows,
    );

    if (updatesSupported) {
      final WindowsAppWindowController window =
          context.dependencyFactory.appWindowController as WindowsAppWindowController;
      _window = window;
      window.prepareUpdateExit = () async {
        final VpnScopeController vpn = VpnScope.vpnControllerOf(context, listen: false);

        try {
          final Completer<String?> vpnPreparation = Completer<String?>();
          vpn.stopForExit(
            mode: VpnExitMode.installation,
            onPrepared: vpnPreparation.complete,
            onError: vpnPreparation.completeError,
          );
          final String? serverId = await vpnPreparation.future;

          final Completer<void> updatePreparation = Completer<void>();
          _controller.prepareForUpdateExit(
            serverId,
            onPrepared: updatePreparation.complete,
            onError: updatePreparation.completeError,
          );
          await updatePreparation.future;
        } catch (_) {
          vpn.cancelExit(mode: VpnExitMode.installation);

          rethrow;
        }
      };
      window.cancelUpdateExit = () async {
        VpnScope.vpnControllerOf(context, listen: false).cancelExit(mode: VpnExitMode.installation);
        await _controller.cancelUpdateExit();
      };
    }

    _controller.loadInitialDataAndStartUpdateChecks();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<AppVersionAndUpdatingController, AppVersionAndUpdatingState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedAppUpdatingScope(
      controller: this,
      updatesSupported: state.updatesSupported,
      version: state.version,
      availableUpdate: state.availableUpdate,
      initialLoadCompleted: state.initialLoadCompleted,
      checkingForUpdates: state.loadingStage == AppUpdatingLoadingStage.checking,
      updating: state.updating,
      canCancelDownload:
          state.loadingStage == AppUpdatingLoadingStage.downloading ||
          state.loadingStage == AppUpdatingLoadingStage.verifying,
      isUpToDate: state.isUpToDate,
      progress: state.progress,
      error: state.error,
      showUpdateIndicator: state.showUpdateIndicator,
      restoreServerId: state.restoreServerId,
      updatedVersion: state.updatedVersion,
      child: widget.child,
    ),
  );

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _controller.removeListener(listener);

  @override
  void checkForUpdates({bool manual = true}) => _controller.checkForUpdates(manual: manual);

  @override
  void updateApplication() => _controller.updateApplication();

  @override
  void retryUpdate() => _controller.retryUpdate();

  @override
  void cancelInstallerDownload() => _controller.cancelInstallerDownload();

  @override
  void resetManualUpdateCheckResult() => _controller.resetManualUpdateCheckResult();

  @override
  void removeUpdateNotification() => _controller.removeUpdateNotification();

  @override
  void dispose() {
    _window?.prepareUpdateExit = null;
    _window?.cancelUpdateExit = null;
    _controller.dispose();
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
