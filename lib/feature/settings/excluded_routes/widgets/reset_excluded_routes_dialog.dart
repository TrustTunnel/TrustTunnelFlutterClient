import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

enum ResetExcludedRoutesDialogAction {
  resetConfirmed,
  resetCancelled,
}

class ResetExcludedRoutesDialog extends StatelessWidget {
  const ResetExcludedRoutesDialog({super.key});

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.resetExcludedRoutesDialogTitle,
    actionsBuilder: (_) => [
      TextButton(
        onPressed: () => context.pop(result: ResetExcludedRoutesDialogAction.resetCancelled),
        child: Text(context.ln.cancel),
      ),
      TextButton(
        onPressed: () => context.pop(result: ResetExcludedRoutesDialogAction.resetConfirmed),
        child: Text(context.ln.reset),
      ),
    ],
  );
}
