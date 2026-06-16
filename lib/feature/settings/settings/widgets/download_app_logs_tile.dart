import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/logs_manager/controller/logs_manager_controller.dart';
import 'package:trusttunnel/feature/settings/logs_manager/controller/logs_manager_state.dart';
import 'package:trusttunnel/widgets/common/custom_arrow_list_tile.dart';
import 'package:trusttunnel/widgets/custom_snack_bar.dart';

class DownloadAppLogsTile extends StatefulWidget {
  const DownloadAppLogsTile({super.key});

  @override
  State<DownloadAppLogsTile> createState() => _DownloadAppLogsTileState();
}

class _DownloadAppLogsTileState extends State<DownloadAppLogsTile> {
  late final LogsManagerController _logsManagerController;

  @override
  void initState() {
    super.initState();

    _logsManagerController = LogsManagerController(
      repository: context.repositoryFactory.exportLogsRepository,
    );
  }

  @override
  Widget build(BuildContext context) => StateConsumer<LogsManagerController, LogsManagerState>(
    controller: _logsManagerController,
    listener: _onLogsManagerStateChanged,
    builder: (context, state, _) => CustomArrowListTile(
      title: context.ln.downloadAppLogs,
      trailingIcon: AssetIcons.fileDownload,
      onTap: () => _logsManagerController.export(
        onArchiveReady: _showArchiveReadySnackBar,
      ),
    ),
  );

  void _onLogsManagerStateChanged(
    BuildContext context,
    LogsManagerController controller,
    LogsManagerState previous,
    LogsManagerState current,
  ) {
    if (current is! LogsManagerErrorState) {
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
                _logsManagerController.share(
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

  @override
  void dispose() {
    _logsManagerController.dispose();

    super.dispose();
  }
}
