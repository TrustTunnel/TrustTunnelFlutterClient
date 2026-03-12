import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_button_section.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_form.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/discard_changes_dialog.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class ExcludedRoutesScreenView extends StatefulWidget {
  const ExcludedRoutesScreenView({
    super.key,
  });

  @override
  State<ExcludedRoutesScreenView> createState() => _ExcludedRoutesScreenViewState();
}

class _ExcludedRoutesScreenViewState extends State<ExcludedRoutesScreenView> {
  late bool hasChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    hasChanges = ExcludedRoutesScope.controllerOf(
      context,
      aspect: ExcludedRoutesAspect.data,
    ).hasChanges;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !hasChanges,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        _showNotSavedChangesWarning(context);
      }
    },
    child: ScaffoldWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.excludedRoutes,
        ),
        body: const Column(
          children: [
            Expanded(
              child: ExcludedRoutesForm(),
            ),
            ExcludedRoutesButtonSection(),
          ],
        ),
      ),
    ),
  );

  void _showNotSavedChangesWarning(BuildContext context) {
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    showDialog(
      context: context,
      builder: (innerContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
        child: DiscardChangesDialog(
          onDiscardPressed: context.pop,
        ),
      ),
    );
  }
}
