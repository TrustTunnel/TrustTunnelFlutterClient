import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class OpenMainWindowOnLoginState {
  final bool enabled;

  const OpenMainWindowOnLoginState({
    required this.enabled,
  });

  const factory OpenMainWindowOnLoginState.initial() = _OpenMainWindowOnLoginInitialState;

  const factory OpenMainWindowOnLoginState.idle({
    required bool enabled,
  }) = _OpenMainWindowOnLoginIdleState;

  const factory OpenMainWindowOnLoginState.loading({
    required bool enabled,
  }) = _OpenMainWindowOnLoginLoadingState;

  const factory OpenMainWindowOnLoginState.error({
    required bool enabled,
    required PresentationException error,
  }) = _OpenMainWindowOnLoginErrorState;

  PresentationException? get error => switch (this) {
    _OpenMainWindowOnLoginErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is _OpenMainWindowOnLoginLoadingState;

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

final class _OpenMainWindowOnLoginInitialState extends _OpenMainWindowOnLoginIdleState {
  const _OpenMainWindowOnLoginInitialState() : super(enabled: false);
}

final class _OpenMainWindowOnLoginIdleState extends OpenMainWindowOnLoginState {
  const _OpenMainWindowOnLoginIdleState({
    required super.enabled,
  });
}

final class _OpenMainWindowOnLoginLoadingState extends OpenMainWindowOnLoginState {
  const _OpenMainWindowOnLoginLoadingState({
    required super.enabled,
  });
}

final class _OpenMainWindowOnLoginErrorState extends OpenMainWindowOnLoginState {
  @override
  final PresentationException error;

  const _OpenMainWindowOnLoginErrorState({
    required super.enabled,
    required this.error,
  });
}
