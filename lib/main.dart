import 'dart:async';

import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/di/common/initialization_helper.dart';
import 'package:vpn/di/dependency_scope.dart';
import 'package:vpn/feature/app/app.dart';
import 'package:vpn/feature/initialization/initialization_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/feature/vpn/widgets/vpn_scope.dart';

void main() {
  runZonedGuarded(
    () {
      final initializationBloc = InitializationBloc(initializationHelper: InitializationHelperIo())
        ..add(const InitializationEvent.init());

      initializationBloc.stream.listen(
        (state) {
          final result = state.initializationResult;

          if (result != null) {
            runApp(
              DependencyScope(
                dependenciesFactory: result.dependenciesFactory,
                blocFactory: result.blocFactory,
                repositoryFactory: result.repositoryFactory,
                child: BlocProvider<ExcludedRoutesBloc>(
                  create: (context) => context.blocFactory.excludedRoutesBloc()
                    ..add(
                      const ExcludedRoutesEvent.init(),
                    ),
                  child: VpnScope(
                    vpnRepository: result.repositoryFactory.vpnRepository,
                    child: const App(),
                  ),
                ),
              ),
            );
          }
        },
      );
    },
    (e, st) {
      print('Error catched in main thread $e');
    },
  );
}
