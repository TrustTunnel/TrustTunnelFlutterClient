import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/scope/excluded_apps_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/scope/excluded_apps_scope.dart';

class ExcludedAppsButtonSection extends StatefulWidget {
  const ExcludedAppsButtonSection({
    super.key,
  });

  @override
  State<ExcludedAppsButtonSection> createState() => _ExcludedAppsButtonSectionState();
}

class _ExcludedAppsButtonSectionState extends State<ExcludedAppsButtonSection> {
  late bool _canSave;

  @override
  void initState() {
    super.initState();
    _canSave = ExcludedAppsScope.controllerOf(context, listen: false).canSave;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dataUpdate = ExcludedAppsScope.controllerOf(context, aspect: ExcludedAppsAspect.data);
    _canSave = dataUpdate.canSave;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: context.isMobileBreakpoint ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
    children: [
      const Divider(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _canSave ? () => _saveExcludedApps(context) : null,
          child: Text(context.ln.save),
        ),
      ),
    ],
  );

  void _saveExcludedApps(BuildContext context) =>
      ExcludedAppsScope.controllerOf(context, listen: false).submit(() => _onExcludedAppsSaved(context));

  void _onExcludedAppsSaved(BuildContext context) {
    if (Navigator.canPop(context)) {
      context.pop();
    }
  }
}
