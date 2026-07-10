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

  const factory AppLoggingState.initial() = _AppLoggingInitialState;

  const factory AppLoggingState.idle({
    required LoggingSecurityType securityType,
    required LoggingLevel level,
  }) = _AppLoggingIdleState;

  const factory AppLoggingState.loading({
    required LoggingSecurityType securityType,
    required LoggingLevel level,
  }) = _AppLoggingLoadingState;

  const factory AppLoggingState.error({
    required LoggingSecurityType securityType,
    required LoggingLevel level,
    required PresentationException error,
  }) = _AppLoggingErrorState;

  PresentationException? get error => switch (this) {
    _AppLoggingErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is _AppLoggingLoadingState;

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

final class _AppLoggingInitialState extends _AppLoggingIdleState {
  const _AppLoggingInitialState()
    : super(
        securityType: LoggingSecurityType.stripped,
        level: LoggingLevel.defaultLevel,
      );
}

final class _AppLoggingIdleState extends AppLoggingState {
  const _AppLoggingIdleState({
    required super.securityType,
    required super.level,
  });
}

final class _AppLoggingLoadingState extends AppLoggingState {
  const _AppLoggingLoadingState({
    required super.securityType,
    required super.level,
  });
}

final class _AppLoggingErrorState extends AppLoggingState {
  @override
  final PresentationException error;

  const _AppLoggingErrorState({
    required super.securityType,
    required super.level,
    required this.error,
  });
}
