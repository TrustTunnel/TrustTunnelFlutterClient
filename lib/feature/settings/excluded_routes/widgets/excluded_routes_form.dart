import 'dart:io';

import 'package:flutter/material.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/domain/service/excluded_routes_spell_check_service.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/widgets/inputs/custom_text_field.dart';

final String _divider = Platform.lineTerminator;

class ExcludedRoutesForm extends StatefulWidget {
  const ExcludedRoutesForm({super.key});

  @override
  State<ExcludedRoutesForm> createState() => _ExcludedRoutesFormState();
}

class _ExcludedRoutesFormState extends State<ExcludedRoutesForm> {
  List<String> _excludedRoutes = [];

  @override
  void initState() {
    super.initState();
    _excludedRoutes = ExcludedRoutesScope.controllerOf(context, listen: false).excludedRoutes;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _excludedRoutes = ExcludedRoutesScope.controllerOf(
      context,
      aspect: ExcludedRoutesAspect.data,
    ).excludedRoutes;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: CustomTextField(
      value: _excludedRoutes.join(_divider),
      spellCheckService: ExcludedRoutesSpellCheckService(
        onChecked: (valid) => _onDataChanged(
          context,
          hasInvalidRoutes: !valid,
        ),
      ),
      hint: context.ln.typeSomething,
      minLines: 40,
      maxLines: 40,
      showClearButton: false,
      onChanged: (excludedRoutes) => _onDataChanged(
        context,
        excludedRoutes: excludedRoutes,
      ),
    ),
  );

  void _onDataChanged(
    BuildContext context, {
    String? excludedRoutes,
    bool? hasInvalidRoutes,
  }) => ExcludedRoutesScope.controllerOf(context, listen: false).changeData(
    excludedRoutes: excludedRoutes?.split(_divider).map((r) => r.trim()).where((r) => r.isNotEmpty).toList(),
    hasInvalidRoutes: hasInvalidRoutes,
  );
}
