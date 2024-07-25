import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/view/widget/excluded_routes_screen_view.dart';

class ExcludedRoutesScreen extends StatelessWidget {
  const ExcludedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider<ExcludedRoutesBloc>(
        create: (context) => context.blocFactory.excludedRoutesBloc()
          ..add(const ExcludedRoutesEvent.init()),
        child: const ExcludedRoutesScreenView(),
      );
}
