import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/reset_excluded_routes_dialog.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';

class ExcludedRoutesButtonSection extends StatefulWidget {
  const ExcludedRoutesButtonSection({
    super.key,
  });

  @override
  State<ExcludedRoutesButtonSection> createState() => _ExcludedRoutesButtonSectionState();
}

class _ExcludedRoutesButtonSectionState extends State<ExcludedRoutesButtonSection> {
  late bool _canSave;
  late bool _canReset;

  @override
  void initState() {
    super.initState();
    _canSave = ExcludedRoutesScope.controllerOf(context, listen: false).canSave;
    _canReset = ExcludedRoutesScope.controllerOf(context, listen: false).canReset;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dataUpdate = ExcludedRoutesScope.controllerOf(context, aspect: ExcludedRoutesAspect.data);
    _canSave = dataUpdate.canSave;
    _canReset = dataUpdate.canReset;
  }

  @override
  Widget build(BuildContext context) {
    final resetButton = OutlinedButton(
      onPressed: _canReset ? () => _resetToDefault(context) : null,
      child: Text(context.ln.resetToDefault),
    );
    final saveButton = FilledButton(
      onPressed: _canSave ? () => _saveExcludedRoutes(context) : null,
      child: Text(context.ln.save),
    );

    return Column(
      crossAxisAlignment: context.isMobileBreakpoint ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: context.isMobileBreakpoint
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    resetButton,
                    const SizedBox(height: 8),
                    saveButton,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    resetButton,
                    const SizedBox(width: 8),
                    saveButton,
                  ],
                ),
        ),
      ],
    );
  }

  void _saveExcludedRoutes(BuildContext context) =>
      ExcludedRoutesScope.controllerOf(context, listen: false).submit(() => _onExcludedRoutesSaved(context));

  Future<void> _resetToDefault(BuildContext context) async {
    final action = await showDialog<ResetExcludedRoutesDialogAction>(
      context: context,
      builder: (_) => const ResetExcludedRoutesDialog(),
    );

    if (!context.mounted || action != ResetExcludedRoutesDialogAction.resetConfirmed) {
      return;
    }

    ExcludedRoutesScope.controllerOf(context, listen: false).resetToDefault();
  }

  void _onExcludedRoutesSaved(BuildContext context) {
    if (Navigator.canPop(context)) {
      context.pop();
    }
  }
}
