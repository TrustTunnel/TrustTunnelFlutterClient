import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/model/logging_settings.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/data/repository/logging_settings_repository.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_state.dart';

typedef AppLoggingCallback = void Function();
typedef AppLoggingSettingsListener = void Function(LoggingSettings settings);

final class AppLoggingController extends BaseStateController<AppLoggingState> with SequentialControllerHandler {
  final LoggingSettingsRepository _settingsRepository;
  final ExportLogsRepository _exportLogsRepository;
  final AppLoggingSettingsListener? _settingsListener;

  AppLoggingController({
    required LoggingSettingsRepository settingsRepository,
    required ExportLogsRepository exportLogsRepository,
    AppLoggingSettingsListener? settingsListener,
    super.initialState = const AppLoggingIdleState(),
  }) : _settingsRepository = settingsRepository,
       _exportLogsRepository = exportLogsRepository,
       _settingsListener = settingsListener;

  void fetch() {
    handle(
      () async {
        if (state.loading) {
          return;
        }

        setState(AppLoggingState.loading(settings: state.settings));
        final settings = await _settingsRepository.getSettings();
        setState(AppLoggingState.idle(settings: settings));
      },
      errorHandler: _onError,
    );
  }

  void setLoggingLevel(
    LoggingLevel level, {
    AppLoggingCallback? onSaved,
  }) => _saveSettings(
    (settings) => settings.copyWith(level: level),
    onSaved: onSaved,
  );

  void setSecurityType(
    LoggingSecurityType securityType, {
    AppLoggingCallback? onSaved,
  }) => _saveSettings(
    (settings) => settings.copyWith(securityType: securityType),
    onSaved: onSaved,
  );

  void deleteLogsAndSetSecurityType(
    LoggingSecurityType securityType, {
    AppLoggingCallback? onDeleted,
    AppLoggingCallback? onSaved,
  }) {
    handle(
      () async {
        if (state.loading) {
          return;
        }

        setState(AppLoggingState.loading(settings: state.settings));
        await _exportLogsRepository.deleteLogs();

        final settings = state.settings.copyWith(securityType: securityType);
        await _settingsRepository.setSettings(settings);

        _settingsListener?.call(settings);
        setState(AppLoggingState.idle(settings: settings));
        _callCallback(onDeleted);
        _callCallback(onSaved);
      },
      errorHandler: _onError,
    );
  }

  void deleteLogs({AppLoggingCallback? onDeleted}) {
    handle(
      () async {
        if (state.loading) {
          return;
        }

        setState(AppLoggingState.loading(settings: state.settings));
        await _exportLogsRepository.deleteLogs();

        setState(AppLoggingState.idle(settings: state.settings));
        _callCallback(onDeleted);
      },
      errorHandler: _onError,
    );
  }

  void _saveSettings(
    LoggingSettings Function(LoggingSettings current) update, {
    AppLoggingCallback? onSaved,
  }) {
    handle(
      () async {
        if (state.loading) {
          return;
        }

        final settings = update(state.settings);
        if (settings == state.settings) {
          return;
        }

        setState(AppLoggingState.loading(settings: state.settings));

        await _settingsRepository.setSettings(settings);
        _settingsListener?.call(settings);

        setState(AppLoggingState.idle(settings: settings));
        _callCallback(onSaved);
      },
      errorHandler: _onError,
    );
  }

  void _onError(Object? error, StackTrace? stackTrace) {
    setState(
      AppLoggingState.error(
        settings: state.settings,
        error: ExceptionUtils.toPresentationException(exception: error),
      ),
    );
  }

  void _callCallback(AppLoggingCallback? callback) {
    if (isDisposed) {
      return;
    }

    try {
      callback?.call();
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }
}
