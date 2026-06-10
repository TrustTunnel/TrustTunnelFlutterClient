import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:trusttunnel/common/controller/controller/controller.dart';
import 'package:trusttunnel/common/logging/app_logger.dart';
import 'package:trusttunnel/common/logging/observers/logging_controller_observer.dart';
import 'package:trusttunnel/di/model/dependency_factory.dart';
import 'package:trusttunnel/di/model/initialization_result.dart';
import 'package:trusttunnel/di/model/repository_factory.dart';

abstract class InitializationHelper {
  Future<InitializationResult> init();
}

class InitializationHelperIo extends InitializationHelper {
  final AppLogger _logger;

  InitializationHelperIo({
    required AppLogger logger,
  }) : _logger = logger;

  @override
  Future<InitializationResult> init() async {
    final bindings = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: bindings);
    await _updateDeviceOrientation();
    BaseController.observer = LoggingControllerObserver(
      logger: _logger,
    );

    final dependenciesFactory = DependencyFactoryImpl(
      logger: _logger,
    );
    await _cleanupStaleLogArchives(dependenciesFactory);

    final repositoryFactory = RepositoryFactoryImpl(
      dependencyFactory: dependenciesFactory,
    );
    final loggingSettings = await repositoryFactory.loggingSettingsRepository.getSettings();
    _logger.updateSettings(loggingSettings);
    _logger.logInfo(
      'App initialization started: logging=$loggingSettings',
      additionalTags: ['app', 'initialization'],
    );

    final initialVpnState = await repositoryFactory.vpnRepository.requestState();

    FlutterNativeSplash.remove();
    _logger.logInfo(
      'App initialization completed',
      additionalTags: ['app', 'initialization'],
    );

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

  Future<void> _cleanupStaleLogArchives(DependencyFactory dependenciesFactory) async {
    try {
      await dependenciesFactory.logsArchiveDataSource.cleanupStaleArchives();
    } on Object catch (error, stackTrace) {
      _logger.logWarning(
        'Stale logs archive cleanup failed',
        error: error.runtimeType,
        stackTrace: stackTrace,
        additionalTags: const ['export_logs'],
      );
    }
  }
}
