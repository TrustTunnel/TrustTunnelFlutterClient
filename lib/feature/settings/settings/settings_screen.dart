import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/utils/url_utils.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/app_logging_screen.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_screen.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_action.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_controller.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_state.dart';
import 'package:trusttunnel/feature/settings/query_log/widgets/query_log_screen.dart';
import 'package:trusttunnel/feature/settings/settings_about/about_screen.dart';
import 'package:trusttunnel/widgets/common/custom_arrow_list_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/custom_snack_bar.dart';
import 'package:trusttunnel/widgets/progress_wrapper.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final LogsExportController _logsExportController;

  @override
  void initState() {
    super.initState();

    _logsExportController = LogsExportController(
      repository: context.repositoryFactory.exportLogsRepository,
      actionListener: _onLogsExportAction,
    );
  }

  @override
  Widget build(BuildContext context) => StateConsumer<LogsExportController, LogsExportState>(
    controller: _logsExportController,
    listener: _onLogsExportStateChanged,
    builder: (context, state, _) => ScaffoldWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.settings,
        ),
        body: ProgressWrapper(
          isLoading: state.processing,
          child: ListView(
            children: [
              CustomArrowListTile(
                title: context.ln.queryLog,
                onTap: () => _pushQueryLogScreen(context),
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.appLogging,
                onTap: () => _pushAppLoggingScreen(context),
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.downloadAppLogs,
                trailingIcon: AssetIcons.fileDownload,
                onTap: _logsExportController.export,
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.excludedRoutes,
                onTap: () => _pushExcludedRoutesScreen(context),
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.followUsOnGithub,
                onTap: _openGithubOrganization,
              ),
              const Divider(),
              CustomArrowListTile(
                title: context.ln.about,
                onTap: () => _pushAboutScreen(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _pushQueryLogScreen(BuildContext context) => context.push(
    const QueryLogScreen(),
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

  void _showArchiveReadySnackBar(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        CustomSnackBar(
          content: Text(context.ln.appLogsExportedSnackbar),
          showCloseIcon: true,
          trailingActions: [
            TextButton(
              onPressed: () {
                messenger.removeCurrentSnackBar();
                _logsExportController.share(
                  subject: context.ln.downloadAppLogs,
                  chooserTitle: context.ln.share,
                );
              },
              child: Text(
                context.ln.share,
                style: context.textTheme.labelLarge?.copyWith(color: context.colors.accent),
              ),
            ),
          ],
        ),
      );
  }

  void _onLogsExportStateChanged(
    BuildContext context,
    LogsExportController controller,
    LogsExportState previous,
    LogsExportState current,
  ) {
    if (current is! LogsExportErrorState) {
      return;
    }
    context.showInfoSnackBar(
      message: context.ln.somethingWentWrongSnackbar,
    );
  }

  void _onLogsExportAction(LogsExportAction action) {
    switch (action) {
      case LogsExportArchiveReadyAction():
        _showArchiveReadySnackBar(context);
      case LogsExportCancelledAction():
        context.showInfoSnackBar(message: context.ln.exportCanceledSnackbar);
      case LogsExportShareDismissedAction():
        break;
      case LogsExportShareUnavailableAction():
        break;
    }
  }

  @override
  void dispose() {
    _logsExportController.dispose();

    super.dispose();
  }
}
