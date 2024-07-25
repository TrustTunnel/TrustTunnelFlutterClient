import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/view/inputs/custom_text_field.dart';

class ExcludedRoutesForm extends StatelessWidget {
  const ExcludedRoutesForm({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<ExcludedRoutesBloc, ExcludedRoutesState>(
          buildWhen: (previous, current) => previous.action == current.action && previous.data != current.data,
          builder: (context, state) {
            return CustomTextField(
              value: state.data,
              hint: context.ln.typeSomething,
              minLines: 40,
              maxLines: 40,
              showClearButton: false,
              onChanged: (excludedRoutes) => _onDataChanged(
                context,
                excludedRoutes: excludedRoutes,
              ),
            );
          },
        ),
      );

  void _onDataChanged(
    BuildContext context, {
    required String excludedRoutes,
  }) =>
      context.read<ExcludedRoutesBloc>().add(
            ExcludedRoutesEvent.dataChanged(
              excludedRoutes: excludedRoutes,
            ),
          );
}
