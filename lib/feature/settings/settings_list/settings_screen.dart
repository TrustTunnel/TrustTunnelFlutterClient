import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/settings/settings_query_log/view/settings_query_log_screen.dart';
import 'package:vpn/view/common/custom_arrow_list_tile.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
        child: Scaffold(
          appBar: CustomAppBar(
            title: context.ln.settings,
          ),
          body: ListView(
            children: [
              CustomArrowListTile(
                title: context.ln.queryLog,
                onTap: () => _pushQueryLogScreen(context),
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.excludedRoutes,
                onTap: _pushExcludedRoutesScreen,
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.followUsOnGithub,
                onTap: _openGithubOrganization,
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.about,
                onTap: _pushAboutScreen,
              ),
            ],
          ),
        ),
      );

  void _pushQueryLogScreen(BuildContext context) => context.push(
        const SettingsQueryLogScreen(),
      );

  // TODO: Implement method to push excluded routes screen
  void _pushExcludedRoutesScreen() {}

  // TODO: Implement method to open GitHub organization
  void _openGithubOrganization() {}

  // TODO: Implement method to push about screen
  void _pushAboutScreen() {}
}
