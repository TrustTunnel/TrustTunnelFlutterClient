import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/model/logging_settings.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/data/repository/logging_settings_repository.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_action.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_state.dart';

typedef AppLoggingActionListener = void Function(AppLoggingAction action);
typedef AppLoggingSettingsListener = void Function(LoggingSettings settings);

final class AppLoggingController extends BaseStateController<AppLoggingState> with SequentialControllerHandler {
  final LoggingSettingsRepository _settingsRepository;
  final ExportLogsRepository _exportLogsRepository;
  final AppLoggingSettingsListener? _settingsListener;
  final AppLoggingActionListener? _actionListener;

  AppLoggingController({
    required LoggingSettingsRepository settingsRepository,
    required ExportLogsRepository exportLogsRepository,
    AppLoggingSettingsListener? settingsListener,
    AppLoggingActionListener? actionListener,
    super.initialState = const AppLoggingIdleState(),
  }) : _settingsRepository = settingsRepository,
       _exportLogsRepository = exportLogsRepository,
       _settingsListener = settingsListener,
       _actionListener = actionListener;

  void fetch() {
    if (state.loading || isProcessing) {
      return;
    }

    handle(
      () async {
        setState(AppLoggingState.loading(settings: state.settings));
        final settings = await _settingsRepository.getSettings();
        setState(AppLoggingState.idle(settings: settings));
      },
      errorHandler: _onError,
    );
  }

  void setLoggingLevel(LoggingLevel level) => _saveSettings(
    (settings) => settings.copyWith(level: level),
  );

  void setSecurityType(LoggingSecurityType securityType) => _saveSettings(
    (settings) => settings.copyWith(securityType: securityType),
  );

  void deleteLogsAndSetSecurityType(LoggingSecurityType securityType) {
    if (state.loading || isProcessing) {
      return;
    }

    handle(
      () async {
        setState(AppLoggingState.loading(settings: state.settings));
        await _exportLogsRepository.deleteLogs();

        final settings = state.settings.copyWith(securityType: securityType);
        await _settingsRepository.setSettings(settings);

        _settingsListener?.call(settings);
        setState(AppLoggingState.idle(settings: settings));
        _callActionListener(const AppLoggingAction.logsDeleted());
      },
      errorHandler: _onError,
    );
  }

  void deleteLogs() {
    if (state.loading || isProcessing) {
      return;
    }

    handle(
      () async {
        setState(AppLoggingState.loading(settings: state.settings));
        await _exportLogsRepository.deleteLogs();

        setState(AppLoggingState.idle(settings: state.settings));
        _callActionListener(const AppLoggingAction.logsDeleted());
      },
      errorHandler: _onError,
    );
  }

  void _saveSettings(LoggingSettings Function(LoggingSettings current) update) {
    if (state.loading || isProcessing) {
      return;
    }

    final settings = update(state.settings);
    if (settings == state.settings) {
      return;
    }

    handle(
      () async {
        setState(AppLoggingState.loading(settings: state.settings));

        await _settingsRepository.setSettings(settings);
        _settingsListener?.call(settings);

        setState(AppLoggingState.idle(settings: settings));
        _callActionListener(const AppLoggingAction.settingsSaved());
      },
      errorHandler: _onError,
    );
  }

  void _onError(Object? error, StackTrace? stackTrace) {
    setState(
      AppLoggingState.error(
        settings: state.settings,
        error: ErrorUtils.toPresentationError(exception: error),
      ),
    );
  }

  void _callActionListener(AppLoggingAction action) {
    if (isDisposed) {
      return;
    }

    try {
      _actionListener?.call(action);
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }
}
