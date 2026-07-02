import 'package:flutter/material.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_state.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/launch_at_login_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/launch_at_login_state.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/open_main_window_on_login_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/open_main_window_on_login_state.dart';
import 'package:trusttunnel/widgets/common/custom_switch_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class LaunchAndConnectionScreen extends StatefulWidget {
  const LaunchAndConnectionScreen({super.key});

  @override
  State<LaunchAndConnectionScreen> createState() => _LaunchAndConnectionScreenState();
}

class _LaunchAndConnectionScreenState extends State<LaunchAndConnectionScreen> {
  late bool _isServersListEmpty;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isServersListEmpty = ServersScope.controllerOf(
      context,
      aspect: ServersScopeAspect.servers,
    ).servers.isEmpty;
  }

  @override
  Widget build(BuildContext context) => StateConsumer<LaunchAtLoginController, LaunchAtLoginState>(
    controller: _launchAtLoginController,
    listener: (context, _, _, current) {
      if (current.error == null) {
        return;
      }
      context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
    },
    builder: (context, launchAtLoginState, _) =>
        StateConsumer<AutoConnectOnLaunchSettingsController, AutoConnectOnLaunchState>(
          controller: _autoConnectOnLaunchSettingsController,
          listener: (context, _, _, current) {
            if (current.error == null) {
              return;
            }
            context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
          },
          builder: (context, autoConnectState, _) =>
              StateConsumer<OpenMainWindowOnLoginController, OpenMainWindowOnLoginState>(
                controller: _openMainWindowOnLoginController,
                listener: (context, _, _, current) {
                  if (current.error == null) {
                    return;
                  }
                  context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
                },
                builder: (context, openMainWindowState, _) => ScaffoldWrapper(
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
                          value: launchAtLoginState.enabled,
                          onChanged: launchAtLoginState.loading ? null : _setLaunchAtSystemLogin,
                        ),
                        CustomSwitchTile(
                          title: context.ln.openHomeScreenAutomatically,
                          value: openMainWindowState.enabled,
                          onChanged: launchAtLoginState.enabled && !openMainWindowState.loading
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
                          subtitle: autoConnectState.enabled && _isServersListEmpty
                              ? context.ln.autoConnectNoServersAdded
                              : null,
                          subtitleColor: context.colors.orange1,
                          value: autoConnectState.enabled,
                          onChanged: autoConnectState.loading ? null : _setAutoConnectOnAppLaunch,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
  );

  void _setLaunchAtSystemLogin(bool value) {
    if (value) {
      _launchAtLoginController.enable();

      return;
    }

    _launchAtLoginController.disable();
  }

  void _setOpenHomeScreenAutomatically(bool value) {
    if (value) {
      _openMainWindowOnLoginController.enable();

      return;
    }

    _openMainWindowOnLoginController.disable();
  }

  void _setAutoConnectOnAppLaunch(bool value) {
    if (value) {
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
