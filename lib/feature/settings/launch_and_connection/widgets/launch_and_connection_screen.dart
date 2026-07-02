import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/widgets/scope/launch_and_connection_scope.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/widgets/scope/launch_and_connection_scope_controller.dart';
import 'package:trusttunnel/widgets/common/custom_switch_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class LaunchAndConnectionScreen extends StatefulWidget {
  const LaunchAndConnectionScreen({super.key});

  @override
  State<LaunchAndConnectionScreen> createState() => _LaunchAndConnectionScreenState();
}

class _LaunchAndConnectionScreenState extends State<LaunchAndConnectionScreen> {
  late LaunchAndConnectionScopeController _controller;
  late bool _isLaunchAtLoginEnabled;
  late bool _isLaunchAtLoginLoading;
  late bool _isOpenMainWindowOnLoginEnabled;
  late bool _isOpenMainWindowOnLoginLoading;
  late bool _isAutoConnectOnLaunchEnabled;
  late bool _isAutoConnectOnLaunchLoading;
  late bool _isServersListEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = LaunchAndConnectionScope.controllerOf(context);
    _isLaunchAtLoginEnabled = _controller.isLaunchAtLoginEnabled;
    _isLaunchAtLoginLoading = _controller.isLaunchAtLoginLoading;
    _isOpenMainWindowOnLoginEnabled = _controller.isOpenMainWindowOnLoginEnabled;
    _isOpenMainWindowOnLoginLoading = _controller.isOpenMainWindowOnLoginLoading;
    _isAutoConnectOnLaunchEnabled = _controller.isAutoConnectOnLaunchEnabled;
    _isAutoConnectOnLaunchLoading = _controller.isAutoConnectOnLaunchLoading;
    _isServersListEmpty = ServersScope.controllerOf(
      context,
      aspect: ServersScopeAspect.servers,
    ).servers.isEmpty;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(
        title: context.ln.launchAndConnection,
        centerTitle: true,
        leadingIconType: AppBarLeadingIconType.back,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.ln.launch,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CustomSwitchTile(
            title: context.ln.launchAppAtSystemLogin,
            value: _isLaunchAtLoginEnabled,
            onChanged: _isLaunchAtLoginLoading ? null : _setLaunchAtSystemLogin,
          ),
          CustomSwitchTile(
            title: context.ln.openHomeScreenAutomatically,
            value: _isOpenMainWindowOnLoginEnabled,
            onChanged: _isLaunchAtLoginEnabled && !_isOpenMainWindowOnLoginLoading
                ? _setOpenHomeScreenAutomatically
                : null,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.ln.connection,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CustomSwitchTile(
            title: context.ln.autoConnectOnAppLaunch,
            subtitle: _isAutoConnectOnLaunchEnabled && _isServersListEmpty
                ? context.ln.autoConnectNoServersAdded
                : null,
            subtitleColor: context.colors.orange1,
            value: _isAutoConnectOnLaunchEnabled,
            onChanged: _isAutoConnectOnLaunchLoading ? null : _setAutoConnectOnAppLaunch,
          ),
        ],
      ),
    ),
  );

  void _setLaunchAtSystemLogin(bool value) => _controller.setLaunchAtLoginEnabled(value);

  void _setOpenHomeScreenAutomatically(bool value) => _controller.setOpenMainWindowOnLoginEnabled(value);

  void _setAutoConnectOnAppLaunch(bool value) => _controller.setAutoConnectOnLaunchEnabled(value);
}
