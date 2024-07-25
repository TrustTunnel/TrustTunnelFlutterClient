import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/view/widget/excluded_routes_button_section.dart';
import 'package:vpn/feature/settings/excluded_routes/view/widget/excluded_routes_form.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class ExcludedRoutesScreenView extends StatelessWidget {
  const ExcludedRoutesScreenView({
    super.key,
  });

  @override
  Widget build(BuildContext context) => BlocListener<ExcludedRoutesBloc, ExcludedRoutesState>(
        listenWhen: (previous, current) => current.action != ExcludedRoutesAction.none,
        listener: (context, state) {
          switch (state.action) {
            case ExcludedRoutesAction.saved:
              context.pop();
            default:
              break;
          }
        },
        child: ScaffoldWrapper(
          child: Scaffold(
            appBar: CustomAppBar(
              title: context.ln.excludedRoutes,
            ),
            body: BlocBuilder<ExcludedRoutesBloc, ExcludedRoutesState>(
              buildWhen: (previous, current) =>
                  previous.action == current.action && previous.loadingStatus != current.loadingStatus,
              builder: (context, state) => state.loadingStatus == ExcludedRoutesLoadingStatus.idle
                  ? const Column(
                      children: [
                        Expanded(
                          child: ExcludedRoutesForm(),
                        ),
                        ExcludedRoutesButtonSection(),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
}
