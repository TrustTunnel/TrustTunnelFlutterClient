import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:trusttunnel/di/model/initialization_result.dart';
import 'package:trusttunnel/di/model/dependency_factory.dart';
import 'package:trusttunnel/di/model/repository_factory.dart';

abstract class InitializationHelper {
  Future<InitializationResult> init();
}

class InitializationHelperIo extends InitializationHelper {
  @override
  Future<InitializationResult> init() async {
    final bindings = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: bindings);
    await _updateDeviceOrientation();

    final dependenciesFactory = DependencyFactoryImpl();

    final repositoryFactory = RepositoryFactoryImpl(
      dependencyFactory: dependenciesFactory,
    );

    final initialVpnState = await repositoryFactory.vpnRepository.requestState();

    FlutterNativeSplash.remove();

    return InitializationResult(
      dependenciesFactory: dependenciesFactory,
      repositoryFactory: repositoryFactory,
      initialVpnState: initialVpnState,
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
