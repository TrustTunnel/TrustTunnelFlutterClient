import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/logging/model/logging_settings.dart';

sealed class AppLoggingState {
  final LoggingSettings settings;

  const AppLoggingState({
    required this.settings,
  });

  const factory AppLoggingState.idle({
    required LoggingSettings settings,
  }) = AppLoggingIdleState;

  const factory AppLoggingState.loading({
    required LoggingSettings settings,
  }) = AppLoggingLoadingState;

  const factory AppLoggingState.error({
    required LoggingSettings settings,
    required PresentationError error,
  }) = AppLoggingErrorState;

  PresentationError? get error => switch (this) {
    AppLoggingErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is AppLoggingLoadingState;

  @override
  String toString() => 'AppLoggingState(type: $runtimeType, settings: $settings, loading: $loading)';
}

final class AppLoggingIdleState extends AppLoggingState {
  const AppLoggingIdleState({
    super.settings = LoggingSettings.defaults,
  });
}

final class AppLoggingLoadingState extends AppLoggingState {
  const AppLoggingLoadingState({
    required super.settings,
  });
}

final class AppLoggingErrorState extends AppLoggingState {
  @override
  final PresentationError error;

  const AppLoggingErrorState({
    required super.settings,
    required this.error,
  });
}
