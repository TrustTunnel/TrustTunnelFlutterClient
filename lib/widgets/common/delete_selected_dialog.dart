import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

class DeleteSelectedDialog extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onDeletePressed;

  const DeleteSelectedDialog({
    super.key,
    required this.title,
    required this.description,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: title,
    scrollable: true,
    content: Text(description),
    actionsBuilder: (spacing) => [
      TextButton(
        onPressed: () => context.pop(),
        child: Text(context.ln.cancel),
      ),
      Theme(
        data: context.theme.copyWith(
          textButtonTheme: context.theme.extension<CustomTextButtonTheme>()?.danger,
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
