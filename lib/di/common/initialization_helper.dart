import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:vpn/di/common/initialization_result.dart';
import 'package:vpn/di/factory/bloc_factory.dart';
import 'package:vpn/di/factory/dependency_factory.dart';
import 'package:vpn/di/factory/repository_factory.dart';

abstract class InitializationHelper {
  Future<InitializationResult> init();
}

class InitializationHelperIo extends InitializationHelper {
  @override
  Future<InitializationResult> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _updateDeviceOrientation();
    PlatformDispatcher.instance.onMetricsChanged = () => _updateDeviceOrientation();

    final dependenciesFactory = DependencyFactoryImpl();

    final repositoryFactory = RepositoryFactoryImpl(
      dependencyFactory: dependenciesFactory,
    );

    final blocFactory = BlocFactoryImpl(
      repositoryFactory: repositoryFactory,
    );

    return InitializationResult(
      dependenciesFactory: dependenciesFactory,
      blocFactory: blocFactory,
      repositoryFactory: repositoryFactory,
    );
  }

  Future<void> _updateDeviceOrientation() async {
    final isWideScreen = PlatformDispatcher.instance.views.every(
      (view) => (view.physicalSize.shortestSide / view.devicePixelRatio) >= 600,
    );
    final legalOrientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      if (isWideScreen) ...[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ];

    await SystemChrome.setPreferredOrientations(legalOrientations);
  }
}
