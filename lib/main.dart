import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/di/common/initialization_helper.dart';
import 'package:vpn/di/dependency_scope.dart';
import 'package:vpn/feature/initialization/initialization_bloc.dart';
import 'package:vpn/feature/navigation/view/navigation_screen.dart';
import 'package:vpn/test_widget.dart';

void main() {
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
            child: const App(),
          ),
        );
      }
    },
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: context.dependencyFactory.lightThemeData,
      home: const TestWidget(),
    );
  }
}
