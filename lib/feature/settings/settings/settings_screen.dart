import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/utils/url_utils.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/app_logging_screen.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_screen.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/widgets/launch_and_connection_screen.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/widgets/scope/launch_and_connection_scope.dart';
import 'package:trusttunnel/feature/settings/query_log/widgets/query_log_screen.dart';
import 'package:trusttunnel/feature/settings/settings/widgets/download_app_logs_tile.dart';
import 'package:trusttunnel/feature/settings/settings_about/about_screen.dart';
import 'package:trusttunnel/widgets/common/custom_arrow_list_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.settings,
        ),
        body: ListView(
          children: [
            CustomArrowListTile(
              title: context.ln.connectionLog,
              onTap: () => _pushQueryLogScreen(context),
            ),
            _SettingsScreenSection(
              sectionTitle: context.ln.general,
              children: [
                if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows)
                  CustomArrowListTile(
                    title: context.ln.launchAndConnection,
                    onTap: () => _pushLaunchAndConnectionScreen(context),
                  ),
                CustomArrowListTile(
                  title: context.ln.excludedRoutes,
                  onTap: () => _pushExcludedRoutesScreen(context),
                ),
                CustomArrowListTile(
                  title: context.ln.appLogging,
                  onTap: () => _pushAppLoggingScreen(context),
                ),
                const DownloadAppLogsTile(),
              ],
            ),
            _SettingsScreenSection(
              sectionTitle: context.ln.about,
              children: [
                CustomArrowListTile(
                  title: context.ln.appVersion,
                  onTap: () => _pushAboutScreen(context),
                ),
                CustomArrowListTile(
                  title: context.ln.github,
                  onTap: _openGithubOrganization,
                  trailingIconColor: context.colors.accent,
                  trailingIcon: AssetIcons.openInNew,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _pushQueryLogScreen(BuildContext context) => context.push(
    const QueryLogScreen(),
  );

  void _pushLaunchAndConnectionScreen(BuildContext context) => context.push(
    const LaunchAndConnectionScope(
      child: LaunchAndConnectionScreen(),
    ),
  );

  void _pushAppLoggingScreen(BuildContext context) => context.push(
    const AppLoggingScreen(),
  );

  void _pushExcludedRoutesScreen(BuildContext context) => context.push(
    const ExcludedRoutesScreen(),
  );

  void _pushAboutScreen(BuildContext context) => context.push(
    const AboutScreen(),
  );

  void _openGithubOrganization() => UrlUtils.openWebPage(UrlUtils.githubTrustTunnelTeam);
}

/// {@template settings_screen}
/// _SettingsScreenSection widget.
/// {@endtemplate}
class _SettingsScreenSection extends StatelessWidget {
  final List<Widget> children;
  final String sectionTitle;

  /// {@macro settings_screen}
  const _SettingsScreenSection({
    required this.sectionTitle,

    this.children = const [],
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
        child: Text(
          sectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      ...children,
    ],
  );
}
