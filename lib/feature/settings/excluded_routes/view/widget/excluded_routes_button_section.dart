import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';

class ExcludedRoutesButtonSection extends StatelessWidget {
  const ExcludedRoutesButtonSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: context.isMobileBreakpoint ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
    children: [
      const Divider(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<ExcludedRoutesBloc, ExcludedRoutesState>(
          builder: (context, state) => FilledButton(
            onPressed: state.hasChanges && state.isValid ? () => _saveExcludedRoutes(context) : null,
            child: Text(context.ln.save),
          ),
        ),
      ),
    ],
  );

  void _saveExcludedRoutes(BuildContext context) => context.read<ExcludedRoutesBloc>().add(
    const ExcludedRoutesEvent.saveExcludedRoutes(),
  );
}
