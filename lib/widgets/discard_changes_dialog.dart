import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_alert_dialog.dart';

/// A confirmation dialog for leaving a form with unsaved changes.
abstract final class DiscardChangesDialog {
  /// Shows the dialog for the current form route that contains [context].
  ///
  /// Closes the form on confirmation if its route is still current. Dismisses
  /// the dialog if navigation removes the form. Completes when either route closes.
  static Future<void> show(BuildContext context) async {
    final formRoute = ModalRoute.of(context);
    if (formRoute == null || !formRoute.isCurrent) {
      return;
    }

    final dialogNavigator = Navigator.of(context, rootNavigator: true);
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final dialogRoute = DialogRoute<_DiscardChangesDialogResult>(
      context: context,
      themes: InheritedTheme.capture(
        from: context,
        to: dialogNavigator.context,
      ),
      barrierColor:
          DialogTheme.of(context).barrierColor ?? Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (dialogContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(dialogContext),
        child: const _DiscardChangesDialogContent(),
      ),
    );

    final result = await Future.any<_DiscardChangesDialogResult?>([
      dialogNavigator.push(dialogRoute),
      formRoute.popped.then((_) => null),
    ]);

    if (dialogNavigator.mounted && dialogRoute.isActive) {
      dialogNavigator.removeRoute(dialogRoute);
    }

    if (result == _DiscardChangesDialogResult.discard && formRoute.isCurrent) {
      formRoute.navigator?.pop();
    }
  }
}

enum _DiscardChangesDialogResult { discard }

class _DiscardChangesDialogContent extends StatelessWidget {
  const _DiscardChangesDialogContent();

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
          onPressed: () => context.pop(result: _DiscardChangesDialogResult.discard),
          child: Text(context.ln.discardChanges),
        ),
      ),
    ],
  );
}
