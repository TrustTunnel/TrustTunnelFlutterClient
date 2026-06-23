import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope_controller.dart';
import 'package:trusttunnel/widgets/common/custom_arrow_list_tile.dart';

class DownloadAppLogsTile extends StatefulWidget {
  const DownloadAppLogsTile({super.key});

  @override
  State<DownloadAppLogsTile> createState() => _DownloadAppLogsTileState();
}

class _DownloadAppLogsTileState extends State<DownloadAppLogsTile> {
  late LogsManagerScopeController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = LogsManagerScope.controllerOf(context);
  }

  @override
  Widget build(BuildContext context) => CustomArrowListTile(
    title: context.ln.downloadAppLogs,
    trailingIcon: AssetIcons.fileDownload,
    onTap: _onExportLogsPressed,
  );

  void _onExportLogsPressed() {
    _controller.exportLogs(
      onArchiveReady: _showArchiveReadySnackBar,
      onError: _onExportLogsError,
    );

    context.showInfoSnackBar(
      message: context.ln.exportingLogs,
      duration: const Duration(minutes: 1),
    );
  }

  void _onExportLogsError() {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
  }

  void _showArchiveReadySnackBar(String filePath) => context.showInfoSnackBar(
    message: context.ln.appLogsExportedSnackbar,
    trailingActions: [
      TextButton(
        onPressed: () {
          context.closeCurrentSnackBar();
          _controller.shareLogs(
            subject: context.ln.downloadAppLogs,
            chooserTitle: context.ln.share,
            filePath: filePath,
            onDismissed: () => context.showInfoSnackBar(message: context.ln.exportCanceledSnackbar),
            onUnavailable: () => context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar),
          );
        },
        child: Text(
          context.ln.share,
          style: context.textTheme.labelLarge?.copyWith(
            color: context.colors.accent,
          ),
        ),
      ),
    ],
  );
}
