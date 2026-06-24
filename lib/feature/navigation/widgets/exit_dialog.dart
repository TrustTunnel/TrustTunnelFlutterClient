import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

enum ExitDialogResult {
  quit,
  dontQuit,
}

class ExitDialog extends StatelessWidget {
  const ExitDialog({super.key});

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.exitDialogTitle,
    titleAlign: TextAlign.center,
    content: Text(
      context.ln.exitDialogDescription,
      textAlign: TextAlign.center,
      style: context.theme.dialogTheme.contentTextStyle,
    ),
    actionsAlignment: MainAxisAlignment.center,
    actionsBuilder: (_) => [
      SizedBox(
        width: 110,
        child: FilledButton(
          onPressed: () => context.pop(result: ExitDialogResult.quit),
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(context.colors.backgroundSystem),
            foregroundColor: WidgetStatePropertyAll(context.colors.neutralBlack),
          ),
          child: Text(context.ln.quit),
        ),
      ),
      SizedBox(
        width: 110,
        child: FilledButton(
          onPressed: () => context.pop(result: ExitDialogResult.dontQuit),
          child: Text(context.ln.dontQuit),
        ),
      ),
    ],
  );
}
