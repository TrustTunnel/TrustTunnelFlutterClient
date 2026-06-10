import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

enum StrippedLoggingDialogAction {
  continueAnyway,
  deleteLogs,
}

class StrippedLoggingDialog extends StatelessWidget {
  const StrippedLoggingDialog({super.key});

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.changeSensitiveDataLoggingDialogTitle,
    content: Text(context.ln.changeSensitiveDataLoggingDialogDescription),
    actionsBuilder: (_) => [
      TextButton(
        onPressed: () => context.pop(result: StrippedLoggingDialogAction.continueAnyway),
        child: Text(context.ln.continueAnyway),
      ),
      Theme(
        data: context.theme.copyWith(
          textButtonTheme: context.theme.extension<CustomTextButtonTheme>()!.danger,
        ),
        child: TextButton(
          onPressed: () => context.pop(result: StrippedLoggingDialogAction.deleteLogs),
          child: Text(context.ln.deleteLogs),
        ),
      ),
    ],
  );
}
