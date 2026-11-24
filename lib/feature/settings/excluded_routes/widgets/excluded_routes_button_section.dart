import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';

class ExcludedRoutesButtonSection extends StatefulWidget {
  final VoidCallback? onSavePressed;

  const ExcludedRoutesButtonSection({
    required this.onSavePressed,
    super.key,
  });

  @override
  State<ExcludedRoutesButtonSection> createState() => _ExcludedRoutesButtonSectionState();
}

class _ExcludedRoutesButtonSectionState extends State<ExcludedRoutesButtonSection> {
  late bool _canSave;

  @override
  void initState() {
    super.initState();
    _canSave = ExcludedRoutesScope.controllerOf(context, listen: false).canSave;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dataUpdate = ExcludedRoutesScope.controllerOf(context, aspect: ExcludedRoutesAspect.data);
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
          onPressed: _canSave ? widget.onSavePressed : null,
          child: Text(context.ln.save),
        ),
      ),
    ],
  );
}
