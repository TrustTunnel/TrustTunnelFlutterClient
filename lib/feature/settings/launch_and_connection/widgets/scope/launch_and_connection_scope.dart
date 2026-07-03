import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_state.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/launch_at_login_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/launch_at_login_state.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/open_main_window_on_login_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/open_main_window_on_login_state.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/widgets/scope/launch_and_connection_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/widgets/scope/launch_and_connection_scope_controller.dart';

class LaunchAndConnectionScope extends StatefulWidget {
  final Widget child;

  const LaunchAndConnectionScope({
    required this.child,
    super.key,
  });

  static LaunchAndConnectionScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    LaunchAndConnectionScopeAspect? aspect,
  }) => _InheritedLaunchAndConnectionScope.controllerOf(
    context,
    listen: listen,
    aspect: aspect,
  );

  @override
  State<LaunchAndConnectionScope> createState() => _LaunchAndConnectionScopeState();
}

class _LaunchAndConnectionScopeState extends State<LaunchAndConnectionScope> {
  late final LaunchAtLoginController _launchAtLoginController;
  late final OpenMainWindowOnLoginController _openMainWindowOnLoginController;
  late final AutoConnectOnLaunchSettingsController _autoConnectOnLaunchSettingsController;

  @override
  void initState() {
    super.initState();

    final repositoryFactory = context.repositoryFactory;
    _launchAtLoginController = LaunchAtLoginController(
      repository: repositoryFactory.launchAtLoginRepository,
    );
    _openMainWindowOnLoginController = OpenMainWindowOnLoginController(
      repository: repositoryFactory.openMainWindowOnLoginRepository,
    );
    _autoConnectOnLaunchSettingsController = AutoConnectOnLaunchSettingsController(
      repository: repositoryFactory.autoConnectOnLaunchSettingsRepository,
    );

    _launchAtLoginController.fetch();
    _openMainWindowOnLoginController.fetch();
    _autoConnectOnLaunchSettingsController.fetch();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<LaunchAtLoginController, LaunchAtLoginState>(
    controller: _launchAtLoginController,
    listener: _showErrorSnackBarIfNeeded,
    builder: (context, launchAtLoginState, _) =>
        StateConsumer<AutoConnectOnLaunchSettingsController, AutoConnectOnLaunchState>(
          controller: _autoConnectOnLaunchSettingsController,
          listener: _showErrorSnackBarIfNeeded,
          builder: (context, autoConnectState, _) =>
              StateConsumer<OpenMainWindowOnLoginController, OpenMainWindowOnLoginState>(
                controller: _openMainWindowOnLoginController,
                listener: _showErrorSnackBarIfNeeded,
                builder: (context, openMainWindowState, _) => _InheritedLaunchAndConnectionScope(
                  launchAtLoginState: launchAtLoginState,
                  openMainWindowOnLoginState: openMainWindowState,
                  autoConnectOnLaunchState: autoConnectState,
                  setLaunchAtLoginEnabled: _setLaunchAtLoginEnabled,
                  setOpenMainWindowOnLoginEnabled: _setOpenMainWindowOnLoginEnabled,
                  setAutoConnectOnLaunchEnabled: _setAutoConnectOnLaunchEnabled,
                  child: widget.child,
                ),
              ),
        ),
  );

  /// Show error snack bar if there is an error in the state of one of the controllers.
  void _showErrorSnackBarIfNeeded(
    BuildContext context,
    Object _,
    Object _,
    Object currentState,
  ) {
    final hasError = switch (currentState) {
      LaunchAtLoginState(:final error) => error != null,
      OpenMainWindowOnLoginState(:final error) => error != null,
      AutoConnectOnLaunchState(:final error) => error != null,
      _ => false,
    };
    if (!hasError) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
  }

  void _setLaunchAtLoginEnabled(bool enabled) {
    if (enabled) {
      _launchAtLoginController.enable();

      return;
    }

    _launchAtLoginController.disable();
  }

  void _setOpenMainWindowOnLoginEnabled(bool enabled) {
    if (enabled) {
      _openMainWindowOnLoginController.enable();

      return;
    }

    _openMainWindowOnLoginController.disable();
  }

  void _setAutoConnectOnLaunchEnabled(bool enabled) {
    if (enabled) {
      _autoConnectOnLaunchSettingsController.enable();

      return;
    }

    _autoConnectOnLaunchSettingsController.disable();
  }

  @override
  void dispose() {
    _autoConnectOnLaunchSettingsController.dispose();
    _openMainWindowOnLoginController.dispose();
    _launchAtLoginController.dispose();

    super.dispose();
  }
}

class _InheritedLaunchAndConnectionScope extends InheritedModel<LaunchAndConnectionScopeAspect>
    implements LaunchAndConnectionScopeController {
  final LaunchAtLoginState _launchAtLoginState;
  final OpenMainWindowOnLoginState _openMainWindowOnLoginState;
  final AutoConnectOnLaunchState _autoConnectOnLaunchState;

  const _InheritedLaunchAndConnectionScope({
    required LaunchAtLoginState launchAtLoginState,
    required OpenMainWindowOnLoginState openMainWindowOnLoginState,
    required AutoConnectOnLaunchState autoConnectOnLaunchState,
    required this.setLaunchAtLoginEnabled,
    required this.setOpenMainWindowOnLoginEnabled,
    required this.setAutoConnectOnLaunchEnabled,
    required super.child,
  }) : _launchAtLoginState = launchAtLoginState,
       _openMainWindowOnLoginState = openMainWindowOnLoginState,
       _autoConnectOnLaunchState = autoConnectOnLaunchState;

  @override
  final void Function(bool enabled) setLaunchAtLoginEnabled;

  @override
  final void Function(bool enabled) setOpenMainWindowOnLoginEnabled;

  @override
  final void Function(bool enabled) setAutoConnectOnLaunchEnabled;

  @override
  bool get isLaunchAtLoginEnabled => _launchAtLoginState.enabled;

  @override
  bool get isLaunchAtLoginLoading => _launchAtLoginState.loading;

  @override
  bool get isOpenMainWindowOnLoginEnabled => _openMainWindowOnLoginState.enabled;

  @override
  bool get isOpenMainWindowOnLoginLoading => _openMainWindowOnLoginState.loading;

  @override
  bool get isAutoConnectOnLaunchEnabled => _autoConnectOnLaunchState.enabled;

  @override
  bool get isAutoConnectOnLaunchLoading => _autoConnectOnLaunchState.loading;

  @override
  bool updateShouldNotify(_InheritedLaunchAndConnectionScope oldWidget) =>
      _launchAtLoginState != oldWidget._launchAtLoginState ||
      _openMainWindowOnLoginState != oldWidget._openMainWindowOnLoginState ||
      _autoConnectOnLaunchState != oldWidget._autoConnectOnLaunchState;

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedLaunchAndConnectionScope oldWidget,
    Set<LaunchAndConnectionScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) {
      return updateShouldNotify(oldWidget);
    }

    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        LaunchAndConnectionScopeAspect.launchAtLogin =>
          isLaunchAtLoginEnabled != oldWidget.isLaunchAtLoginEnabled ||
              isLaunchAtLoginLoading != oldWidget.isLaunchAtLoginLoading,
        LaunchAndConnectionScopeAspect.openMainWindowOnLogin =>
          isOpenMainWindowOnLoginEnabled != oldWidget.isOpenMainWindowOnLoginEnabled ||
              isOpenMainWindowOnLoginLoading != oldWidget.isOpenMainWindowOnLoginLoading,
        LaunchAndConnectionScopeAspect.autoConnectOnLaunch =>
          isAutoConnectOnLaunchEnabled != oldWidget.isAutoConnectOnLaunchEnabled ||
              isAutoConnectOnLaunchLoading != oldWidget.isAutoConnectOnLaunchLoading,
      };

      if (hasAnyChanges) {
        return true;
      }
    }

    return false;
  }

  static _InheritedLaunchAndConnectionScope controllerOf(
    BuildContext context, {
    bool listen = true,
    LaunchAndConnectionScopeAspect? aspect,
  }) =>
      _inheritFrom(
        context,
        listen: listen,
        aspect: aspect,
      ) ??
      _notFoundInheritedWidgetOfExactType();

  static _InheritedLaunchAndConnectionScope? _inheritFrom(
    BuildContext context, {
    bool listen = true,
    LaunchAndConnectionScopeAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedLaunchAndConnectionScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedLaunchAndConnectionScope>()?.widget
            as _InheritedLaunchAndConnectionScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<LaunchAndConnectionScopeAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
