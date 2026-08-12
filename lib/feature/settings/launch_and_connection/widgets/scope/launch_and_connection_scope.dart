import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/launch_at_login_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/open_main_window_on_login_controller.dart';
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
  late final Listenable _controllersMergedListenable;

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

    _controllersMergedListenable = Listenable.merge(
      [
        _launchAtLoginController,
        _openMainWindowOnLoginController,
        _autoConnectOnLaunchSettingsController,
      ],
    )..addListener(_showErrorSnackBarIfNeeded);

    _launchAtLoginController.fetch();
    _openMainWindowOnLoginController.fetch();
    _autoConnectOnLaunchSettingsController.fetch();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controllersMergedListenable,
    builder: (BuildContext context, Widget? child) => _InheritedLaunchAndConnectionScope(
      isLaunchAtLoginEnabled: _launchAtLoginController.state.enabled,
      isLaunchAtLoginLoading: _launchAtLoginController.state.loading,
      isOpenMainWindowOnLoginEnabled: _openMainWindowOnLoginController.state.enabled,
      isOpenMainWindowOnLoginLoading: _openMainWindowOnLoginController.state.loading,
      isAutoConnectOnLaunchEnabled: _autoConnectOnLaunchSettingsController.state.enabled,
      isAutoConnectOnLaunchLoading: _autoConnectOnLaunchSettingsController.state.loading,
      setLaunchAtLoginEnabled: _setLaunchAtLoginEnabled,
      setOpenMainWindowOnLoginEnabled: _setOpenMainWindowOnLoginEnabled,
      setAutoConnectOnLaunchEnabled: _setAutoConnectOnLaunchEnabled,
      child: widget.child,
    ),
  );

  /// Show error snack bar if there is an error in the state of one of the controllers.
  void _showErrorSnackBarIfNeeded() {
    final bool hasError;

    if (_launchAtLoginController.state.error != null ||
        _openMainWindowOnLoginController.state.error != null ||
        _autoConnectOnLaunchSettingsController.state.error != null) {
      hasError = true;
    } else {
      hasError = false;
    }

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
  const _InheritedLaunchAndConnectionScope({
    required this.isLaunchAtLoginEnabled,
    required this.isLaunchAtLoginLoading,
    required this.isOpenMainWindowOnLoginEnabled,
    required this.isOpenMainWindowOnLoginLoading,
    required this.isAutoConnectOnLaunchEnabled,
    required this.isAutoConnectOnLaunchLoading,
    required this.setLaunchAtLoginEnabled,
    required this.setOpenMainWindowOnLoginEnabled,
    required this.setAutoConnectOnLaunchEnabled,
    required super.child,
  });

  @override
  final bool isLaunchAtLoginEnabled;

  @override
  final bool isLaunchAtLoginLoading;

  @override
  final bool isOpenMainWindowOnLoginEnabled;

  @override
  final bool isOpenMainWindowOnLoginLoading;

  @override
  final bool isAutoConnectOnLaunchEnabled;

  @override
  final bool isAutoConnectOnLaunchLoading;

  @override
  final void Function(bool enabled) setLaunchAtLoginEnabled;

  @override
  final void Function(bool enabled) setOpenMainWindowOnLoginEnabled;

  @override
  final void Function(bool enabled) setAutoConnectOnLaunchEnabled;

  @override
  bool updateShouldNotify(_InheritedLaunchAndConnectionScope oldWidget) =>
      isLaunchAtLoginEnabled != oldWidget.isLaunchAtLoginEnabled ||
      isLaunchAtLoginLoading != oldWidget.isLaunchAtLoginLoading ||
      isOpenMainWindowOnLoginEnabled != oldWidget.isOpenMainWindowOnLoginEnabled ||
      isOpenMainWindowOnLoginLoading != oldWidget.isOpenMainWindowOnLoginLoading ||
      isAutoConnectOnLaunchEnabled != oldWidget.isAutoConnectOnLaunchEnabled ||
      isAutoConnectOnLaunchLoading != oldWidget.isAutoConnectOnLaunchLoading ||
      setLaunchAtLoginEnabled != oldWidget.setLaunchAtLoginEnabled ||
      setOpenMainWindowOnLoginEnabled != oldWidget.setOpenMainWindowOnLoginEnabled ||
      setAutoConnectOnLaunchEnabled != oldWidget.setAutoConnectOnLaunchEnabled;

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
