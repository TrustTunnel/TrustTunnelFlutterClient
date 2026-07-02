import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class OpenMainWindowOnLoginState {
  final bool enabled;

  const OpenMainWindowOnLoginState({
    required this.enabled,
  });

  const factory OpenMainWindowOnLoginState.initial() = OpenMainWindowOnLoginInitialState;

  const factory OpenMainWindowOnLoginState.idle({
    required bool enabled,
  }) = OpenMainWindowOnLoginIdleState;

  const factory OpenMainWindowOnLoginState.loading({
    required bool enabled,
  }) = OpenMainWindowOnLoginLoadingState;

  const factory OpenMainWindowOnLoginState.error({
    required bool enabled,
    required PresentationException error,
  }) = OpenMainWindowOnLoginErrorState;

  PresentationException? get error => switch (this) {
    OpenMainWindowOnLoginErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is OpenMainWindowOnLoginLoadingState;

  @override
  int get hashCode => Object.hash(
    enabled,
    error,
    loading,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenMainWindowOnLoginState &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          error == other.error &&
          loading == other.loading;

  @override
  String toString() => 'OpenMainWindowOnLoginState(type: $runtimeType, enabled: $enabled, loading: $loading)';
}

final class OpenMainWindowOnLoginInitialState extends OpenMainWindowOnLoginIdleState {
  const OpenMainWindowOnLoginInitialState() : super(enabled: false);
}

final class OpenMainWindowOnLoginIdleState extends OpenMainWindowOnLoginState {
  const OpenMainWindowOnLoginIdleState({
    required super.enabled,
  });
}

final class OpenMainWindowOnLoginLoadingState extends OpenMainWindowOnLoginState {
  const OpenMainWindowOnLoginLoadingState({
    required super.enabled,
  });
}

final class OpenMainWindowOnLoginErrorState extends OpenMainWindowOnLoginState {
  @override
  final PresentationException error;

  const OpenMainWindowOnLoginErrorState({
    required super.enabled,
    required this.error,
  });
}
