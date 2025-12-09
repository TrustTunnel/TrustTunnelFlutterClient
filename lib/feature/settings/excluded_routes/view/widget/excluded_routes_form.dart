import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/domain/excluded_routes_spell_check_service.dart';
import 'package:vpn/view/inputs/custom_text_field.dart';

final String _divider = Platform.lineTerminator;

class ExcludedRoutesForm extends StatelessWidget {
  const ExcludedRoutesForm({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: BlocBuilder<ExcludedRoutesBloc, ExcludedRoutesState>(
      buildWhen: (previous, current) => previous.action == current.action,
      builder: (context, state) => CustomTextField(
        value: state.excludedRoutes.join(_divider),
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
    ),
  );

  void _onDataChanged(
    BuildContext context, {
    String? excludedRoutes,
    bool? hasInvalidRoutes,
  }) => context.read<ExcludedRoutesBloc>().add(
    ExcludedRoutesEvent.dataChanged(
      excludedRoutes: excludedRoutes?.split(_divider).map((r) => r.trim()).where((r) => r.isNotEmpty).toList(),
      hasInvalidRoutes: hasInvalidRoutes,
    ),
  );
}
