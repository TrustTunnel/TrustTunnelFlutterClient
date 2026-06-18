import 'dart:async';
import 'dart:ui';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/common/controller/controller/controller.dart';
import 'package:trusttunnel/common/logging/app_logger.dart';
import 'package:trusttunnel/common/logging/appenders/custom_console_appender.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/observers/logging_controller_observer.dart';
import 'package:trusttunnel/common/logging/sanitizer/log_sanitizer.dart';
import 'package:trusttunnel/common/logging/utils/containment_file_util.dart';
import 'package:trusttunnel/data/repository/logging_settings_repository.dart';
import 'package:trusttunnel/di/model/dependency_factory.dart';
import 'package:trusttunnel/di/model/initialization_result.dart';
import 'package:trusttunnel/di/model/repository_factory.dart';

abstract class InitializationHelper {
  const InitializationHelper();

  Future<InitializationResult> init();
}

class InitializationHelperIo extends InitializationHelper {
  const InitializationHelperIo();

  @override
  Future<InitializationResult> init() async {
    final bindings = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: bindings);
    await _updateDeviceOrientation();

    BaseController.observer = const LoggingControllerObserver();

    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

    final dependenciesFactory = DependencyFactoryImpl(sharedPreferences: sharedPreferences);
    await _cleanupStaleLogArchives(dependenciesFactory);

    final repositoryFactory = RepositoryFactoryImpl(
      dependencyFactory: dependenciesFactory,
    );

    await _configureLogging(
      repositoryFactory.loggingSettingsRepository,
      dependenciesFactory,
    );

    logger.logInfo(
      'App initialization started',
      additionalTags: ['app', 'initialization'],
    );

    final initialVpnState = await repositoryFactory.vpnRepository.requestState();

    FlutterNativeSplash.remove();

    logger.logInfo(
      'App initialization completed',
      additionalTags: ['app', 'initialization'],
    );

    return InitializationResult(
      dependenciesFactory: dependenciesFactory,
      repositoryFactory: repositoryFactory,
      initialVpnState: initialVpnState,
    );
  }

  Future<void> _configureLogging(
    LoggingSettingsRepository loggingSettingsRepository,
    DependencyFactoryImpl dependenciesFactory,
  ) async {
    final loggingSettings = await Future.wait([
      loggingSettingsRepository.getLoggingLevel(),
      loggingSettingsRepository.getSecurityType(),
    ]);

    final loggingLevel = loggingSettings[0] as LoggingLevel;
    final securityType = loggingSettings[1] as LoggingSecurityType;

    (logger as AppLogger).updateSettings(
      loggingLevel: loggingLevel,
      sanitizer: LogSanitizer(
        securityType: securityType,
      ),
    );

    final consoleAppender = CustomConsoleAppender();
    consoleAppender.attachToLogger(logger);

    final String path;
    final LogStorage storage;

    path = await ContainmentFileUtil.getPlatformContainmentDirectoryPath(
      'log',
      appName: 'TrustTunnel',
      directoryName: 'Logs',
    );

    storage = FileLogStorage(
      formatter: const DataLoggerFormatter(
        loggingData: [
          LoggingData.time(),
          LoggingData.level(),
          LoggingData.trace(),
          LoggingData.separator('\n'),
          LoggingData.message(),
          LoggingData.separator('\n'),
          LoggingData.error(),
          LoggingData.separator('\n'),
          LoggingData.stackTrace(),
          LoggingData.separator('\n\x1E'),
        ],
      ),
    );

    final fileAppender = FileLogAppender(
      logStorage: storage,
      filePath: path,
      rotationFileController: RotationFileController(
        containmentDaysDuration: 7,
        rotationSizeLimit: 1024 * 1024 * 30,
        rotationFileLimit: 1024 * 1024 * 3,
      ),
    );
    fileAppender.attachToLogger(logger);

    dependenciesFactory.fileLogAppender = fileAppender;
    dependenciesFactory.logStorage = storage;
    dependenciesFactory.logDirectoryPath = path;

    logger.logInfo(
      'Logger configured with level: $loggingLevel and security type: $securityType',
      additionalTags: ['app', 'initialization'],
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
      logger.logWarning(
        'Stale logs archive cleanup failed',
        error: error.runtimeType,
        stackTrace: stackTrace,
        additionalTags: const ['export_logs'],
      );
    }
  }
}
