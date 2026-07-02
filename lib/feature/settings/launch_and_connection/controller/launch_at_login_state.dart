import 'package:trusttunnel/common/error/model/presentation_exception.dart';

sealed class LaunchAtLoginState {
  final bool enabled;

  const LaunchAtLoginState({
    required this.enabled,
  });

  const factory LaunchAtLoginState.initial() = LaunchAtLoginInitialState;

  const factory LaunchAtLoginState.idle({
    required bool enabled,
  }) = LaunchAtLoginIdleState;

  const factory LaunchAtLoginState.loading({
    required bool enabled,
  }) = LaunchAtLoginLoadingState;

  const factory LaunchAtLoginState.error({
    required bool enabled,
    required PresentationException error,
  }) = LaunchAtLoginErrorState;

  PresentationException? get error => switch (this) {
    LaunchAtLoginErrorState(:final error) => error,
    _ => null,
  };

  bool get loading => this is LaunchAtLoginLoadingState;

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

final class LaunchAtLoginInitialState extends LaunchAtLoginIdleState {
  const LaunchAtLoginInitialState() : super(enabled: false);
}

final class LaunchAtLoginIdleState extends LaunchAtLoginState {
  const LaunchAtLoginIdleState({
    required super.enabled,
  });
}

final class LaunchAtLoginLoadingState extends LaunchAtLoginState {
  const LaunchAtLoginLoadingState({
    required super.enabled,
  });
}

final class LaunchAtLoginErrorState extends LaunchAtLoginState {
  @override
  final PresentationException error;

  const LaunchAtLoginErrorState({
    required super.enabled,
    required this.error,
  });
}
