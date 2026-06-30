import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';

sealed class AppLoggingState {
  final LoggingSecurityType securityType;
  final LoggingLevel level;

  const AppLoggingState({
    required this.securityType,
    required this.level,
  });

  const factory AppLoggingState.initial() = AppLoggingInitialState;

  const factory AppLoggingState.idle({
    required LoggingSecurityType securityType,
    required LoggingLevel level,
  }) = AppLoggingIdleState;

  const factory AppLoggingState.loading({
    required LoggingSecurityType securityType,
    required LoggingLevel level,
  }) = AppLoggingLoadingState;

  const factory AppLoggingState.error({
    required LoggingSecurityType securityType,
    required LoggingLevel level,
    required PresentationException error,
  }) = AppLoggingErrorState;

  PresentationException? get error => switch (this) {
    AppLoggingErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is AppLoggingLoadingState;

  @override
  int get hashCode => Object.hash(
    securityType,
    level,
    error,
    loading,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLoggingState &&
          runtimeType == other.runtimeType &&
          securityType == other.securityType &&
          level == other.level &&
          error == other.error &&
          loading == other.loading;

  @override
  String toString() =>
      'AppLoggingState(type: $runtimeType, securityType: $securityType, level: $level, loading: $loading)';
}

final class AppLoggingInitialState extends AppLoggingIdleState {
  const AppLoggingInitialState()
    : super(
        securityType: LoggingSecurityType.stripped,
        level: LoggingLevel.defaultLevel,
      );
}

final class AppLoggingIdleState extends AppLoggingState {
  const AppLoggingIdleState({
    required super.securityType,
    required super.level,
  });
}

final class AppLoggingLoadingState extends AppLoggingState {
  const AppLoggingLoadingState({
    required super.securityType,
    required super.level,
  });
}

final class AppLoggingErrorState extends AppLoggingState {
  @override
  final PresentationException error;

  const AppLoggingErrorState({
    required super.securityType,
    required super.level,
    required this.error,
  });
}
