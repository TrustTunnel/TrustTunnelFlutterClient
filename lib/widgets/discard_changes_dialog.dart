import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

/// Shows a full-window confirmation dialog for the form that contains [context].
///
/// Confirmation closes the form if its route is still current. If the form
/// route closes first, this function dismisses its dialog.
void showDiscardChangesDialog(BuildContext context) {
  final formRoute = ModalRoute.of(context);
  if (formRoute == null || !formRoute.isCurrent) {
    return;
  }

  final dialogNavigator = Navigator.of(context, rootNavigator: true);
  final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  final dialogRoute = DialogRoute<void>(
    context: context,
    themes: InheritedTheme.capture(
      from: context,
      to: dialogNavigator.context,
    ),
    barrierColor: DialogTheme.of(context).barrierColor ?? Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (dialogContext) => ScaffoldMessengerProvider(
      value: parentScaffoldMessenger ?? ScaffoldMessenger.of(dialogContext),
      child: DiscardChangesDialog(
        onDiscardPressed: () {
          if (formRoute.isCurrent) {
            formRoute.navigator?.pop();
          }
        },
      ),
    ),
  );

  unawaited(dialogNavigator.push(dialogRoute));
  unawaited(
    formRoute.popped.then((_) {
      if (dialogNavigator.mounted && dialogRoute.isActive) {
        dialogNavigator.removeRoute(dialogRoute);
      }
    }),
  );
}

/// A confirmation dialog for leaving a form with unsaved changes.
class DiscardChangesDialog extends StatelessWidget {
  /// Called after the dialog closes when the user confirms.
  final VoidCallback onDiscardPressed;

  const DiscardChangesDialog({
    required this.onDiscardPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) => CustomAlertDialog(
    title: context.ln.discardChangesDialogTitle,
    scrollable: true,
    content: Text(context.ln.discardChangesDialogDescription),
    actionsBuilder: (spacing) => [
      TextButton(
        onPressed: context.pop,
        child: Text(context.ln.cancel),
      ),
      Theme(
        data: context.theme.copyWith(
          textButtonTheme: context.theme.extension<CustomTextButtonTheme>()?.danger,
        ),
        child: TextButton(
          onPressed: () {
            context.pop();
            onDiscardPressed();
          },
          child: Text(context.ln.discardChanges),
        ),
      ),
    ],
  );
}
