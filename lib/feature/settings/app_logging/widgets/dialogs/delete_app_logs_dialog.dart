import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

enum DeleteAppLogsDialogAction {
  deleteConfirmed,
  deleteCancelled,
}

class DeleteAppLogsDialog extends StatelessWidget {
  const DeleteAppLogsDialog({super.key});

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.deleteAppLogsDialogTitle,
    content: Text(context.ln.deleteAppLogsDialogDescription),
    actionsBuilder: (_) => [
      TextButton(
        onPressed: () => context.pop(result: DeleteAppLogsDialogAction.deleteCancelled),
        child: Text(context.ln.cancel),
      ),
      Theme(
        data: context.theme.copyWith(
          textButtonTheme: context.theme.extension<CustomTextButtonTheme>()!.danger,
        ),
        child: TextButton(
          onPressed: () => context.pop(result: DeleteAppLogsDialogAction.deleteConfirmed),
          child: Text(context.ln.delete),
        ),
      ),
    ],
  );
}
