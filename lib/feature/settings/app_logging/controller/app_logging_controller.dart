import 'package:flutter/material.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/repository/logging_settings_repository.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_state.dart';

final class AppLoggingController extends BaseStateController<AppLoggingState> with SequentialControllerHandler {
  final LoggingSettingsRepository _settingsRepository;

  AppLoggingController({
    required LoggingSettingsRepository settingsRepository,
    super.initialState = const AppLoggingState.initial(),
  }) : _settingsRepository = settingsRepository;

  void fetch() => handle(
    () async {
      setState(
        AppLoggingState.loading(
          securityType: state.securityType,
          level: state.level,
        ),
      );

      final results = await Future.wait([_settingsRepository.getLoggingLevel(), _settingsRepository.getSecurityType()]);
      final level = results[0] as LoggingLevel;
      final securityType = results[1] as LoggingSecurityType;

      setState(
        AppLoggingState.idle(
          securityType: securityType,
          level: level,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void setLoggingLevel(
    LoggingLevel level, {
    ValueChanged<LoggingLevel>? onUpdated,
  }) => handle(
    () async {
      setState(
        AppLoggingState.loading(
          securityType: state.securityType,
          level: state.level,
        ),
      );

      await _settingsRepository.setLoggingLevel(level);

      setState(
        AppLoggingState.idle(
          securityType: state.securityType,
          level: level,
        ),
      );

      onUpdated?.call(level);
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void setSecurityType(
    LoggingSecurityType securityType, {
    ValueChanged<LoggingSecurityType>? onUpdated,
  }) => handle(
    () async {
      setState(
        AppLoggingState.loading(
          securityType: state.securityType,
          level: state.level,
        ),
      );

      await _settingsRepository.setSecurityType(securityType);

      setState(
        AppLoggingState.idle(
          securityType: securityType,
          level: state.level,
        ),
      );

      onUpdated?.call(securityType);
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void _onError(Object? error, StackTrace? stackTrace) => setState(
    AppLoggingState.error(
      securityType: state.securityType,
      level: state.level,
      error: ExceptionUtils.toPresentationException(exception: error),
    ),
  );

  void _onCompleted() => setState(
    AppLoggingState.idle(
      securityType: state.securityType,
      level: state.level,
    ),
  );
}
