import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_controller.dart';
import 'package:trusttunnel/feature/settings/logs_export/controller/logs_export_state.dart';
import 'package:trusttunnel/widgets/common/custom_arrow_list_tile.dart';
import 'package:trusttunnel/widgets/custom_snack_bar.dart';

class DownloadAppLogsTile extends StatefulWidget {
  const DownloadAppLogsTile({super.key});

  @override
  State<DownloadAppLogsTile> createState() => _DownloadAppLogsTileState();
}

class _DownloadAppLogsTileState extends State<DownloadAppLogsTile> {
  late final LogsExportController _logsExportController;

  @override
  void initState() {
    super.initState();

    _logsExportController = LogsExportController(
      repository: context.repositoryFactory.exportLogsRepository,
    );
  }

  @override
  Widget build(BuildContext context) => StateConsumer<LogsExportController, LogsExportState>(
    controller: _logsExportController,
    listener: _onLogsExportStateChanged,
    builder: (context, state, _) => CustomArrowListTile(
      title: context.ln.downloadAppLogs,
      trailingIcon: AssetIcons.fileDownload,
      onTap: () => _logsExportController.export(
        onArchiveReady: _showArchiveReadySnackBar,
        onCancelled: _showExportCancelledSnackBar,
      ),
    ),
  );

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

  void _showArchiveReadySnackBar() {
    if (!mounted) {
      return;
    }

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

  void _showExportCancelledSnackBar() {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.exportCanceledSnackbar);
  }

  @override
  void dispose() {
    _logsExportController.dispose();

    super.dispose();
  }
}
