import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

class RoutingDetailsDeleteRulesDialog extends StatelessWidget {
  final String profileName;
  final VoidCallback onDeletePressed;

  const RoutingDetailsDeleteRulesDialog({
    super.key,
    required this.profileName,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.deleteAllRulesDialogTitle,
    scrollable: true,
    content: Text(context.ln.deleteAllRulesDialogDescription(profileName)),
    actionsBuilder: (spacing) => [
      TextButton(
        onPressed: () => context.pop(),
        child: Text(context.ln.cancel),
      ),
      Theme(
        data: context.theme.copyWith(
          textButtonTheme: context.theme.extension<CustomTextButtonTheme>()!.danger,
        ),
        child: TextButton(
          onPressed: () {
            context.pop();
            onDeletePressed();
          },
          child: Text(context.ln.delete),
        ),
      ),
    ],
  );
}
