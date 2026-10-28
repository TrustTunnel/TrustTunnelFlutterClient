import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

/// Restores the last VPN connection when automatic connection on launch is enabled.
class AutoConnectOnLaunchSettingsScope extends StatefulWidget {
  final Widget child;

  const AutoConnectOnLaunchSettingsScope({
    required this.child,
    super.key,
  });

  @override
  State<AutoConnectOnLaunchSettingsScope> createState() => _AutoConnectOnLaunchSettingsScopeState();
}

class _AutoConnectOnLaunchSettingsScopeState extends State<AutoConnectOnLaunchSettingsScope> {
  late final AutoConnectOnLaunchSettingsController _controller;
  bool _launchRequested = false;
  AppVersionAndUpdatingScopeController? _updatesController;

  @override
  void initState() {
    super.initState();
    _controller = AutoConnectOnLaunchSettingsController(
      repository: context.repositoryFactory.autoConnectOnLaunchSettingsRepository,
    );
    _controller.addListener(_connectToLastServerIfNeeded);
    _controller.fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppVersionAndUpdatingScopeController updatesController = AppVersionAndUpdatingScope.controllerOf(
      context: context,
      listen: false,
    );
    if (!identical(updatesController, _updatesController)) {
      _updatesController?.removeListener(_connectToLastServerIfNeeded);
      _updatesController = updatesController;
      updatesController.addListener(_connectToLastServerIfNeeded);
    }

    _connectToLastServerIfNeeded();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _connectToLastServerIfNeeded() {
    final state = _controller.state;
    final AppVersionAndUpdatingScopeController? updatesController = _updatesController;
    final bool updatesReady = updatesController != null && updatesController.initialLoadCompleted;
    if (!updatesReady) {
      return;
    }
    if (!mounted || _launchRequested || state.initial || state.loading || state.connectOnLaunchHandled) {
      return;
    }

    _launchRequested = true;
    _controller.markConnectOnLaunchHandled();

    final String? serverId =
        updatesController.restoreServerId ?? (state.error == null && state.enabled ? state.lastServerId : null);
    if (serverId != null) {
      // The VPN scope waits for dependencies and gives manual commands priority.
      VpnScope.vpnControllerOf(context, listen: false).connectToServer(serverId, isFromAutomaticLaunch: true);
    }
  }

  @override
  void dispose() {
    _updatesController?.removeListener(_connectToLastServerIfNeeded);
    _controller.removeListener(_connectToLastServerIfNeeded);
    _controller.dispose();
    super.dispose();
  }
}
