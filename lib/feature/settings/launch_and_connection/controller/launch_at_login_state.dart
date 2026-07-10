import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class LaunchAtLoginState {
  final bool enabled;

  const LaunchAtLoginState({
    required this.enabled,
  });

  const factory LaunchAtLoginState.initial() = _LaunchAtLoginInitialState;

  const factory LaunchAtLoginState.idle({
    required bool enabled,
  }) = _LaunchAtLoginIdleState;

  const factory LaunchAtLoginState.loading({
    required bool enabled,
  }) = _LaunchAtLoginLoadingState;

  const factory LaunchAtLoginState.error({
    required bool enabled,
    required PresentationException error,
  }) = _LaunchAtLoginErrorState;

  PresentationException? get error => switch (this) {
    _LaunchAtLoginErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is _LaunchAtLoginLoadingState;

  @override
  int get hashCode => Object.hash(
    enabled,
    error,
    loading,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaunchAtLoginState &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          error == other.error &&
          loading == other.loading;

  @override
  String toString() => 'LaunchAtLoginState(type: $runtimeType, enabled: $enabled, loading: $loading)';
}

final class _LaunchAtLoginInitialState extends _LaunchAtLoginIdleState {
  const _LaunchAtLoginInitialState() : super(enabled: false);
}

final class _LaunchAtLoginIdleState extends LaunchAtLoginState {
  const _LaunchAtLoginIdleState({
    required super.enabled,
  });
}

final class _LaunchAtLoginLoadingState extends LaunchAtLoginState {
  const _LaunchAtLoginLoadingState({
    required super.enabled,
  });
}

final class _LaunchAtLoginErrorState extends LaunchAtLoginState {
  @override
  final PresentationException error;

  const _LaunchAtLoginErrorState({
    required super.enabled,
    required this.error,
  });
}
