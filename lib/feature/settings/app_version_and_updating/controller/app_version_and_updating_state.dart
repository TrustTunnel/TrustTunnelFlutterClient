import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/app_updating_operation_state.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

enum AppUpdatingLoadingStage {
  checking,
  downloading,
  verifying,
  installing,
}

@immutable
sealed class AppVersionAndUpdatingState {
  final bool updatesSupported;
  final AppVersion? version;
  final AvailableAppUpdate? availableUpdate;
  final String? restoreServerId;
  final String? updatedVersion;
  final AppUpdatingOperationState operation;

  const AppVersionAndUpdatingState._({
    required this.updatesSupported,
    this.version,
    this.availableUpdate,
    this.restoreServerId,
    this.updatedVersion,
    this.operation = const AppUpdatingOperationState(),
  });

  AppVersionAndUpdatingState._from(AppVersionAndUpdatingState previousState)
    : updatesSupported = previousState.updatesSupported,
      version = previousState.version,
      availableUpdate = previousState.availableUpdate,
      restoreServerId = previousState.restoreServerId,
      updatedVersion = previousState.updatedVersion,
      operation = previousState.operation;

  const factory AppVersionAndUpdatingState.initial({required bool updatesSupported}) =
      _AppVersionAndUpdatingInitialState;

  factory AppVersionAndUpdatingState.idle({
    required AppVersionAndUpdatingState previousState,
    bool isUpToDate,
  }) = _AppVersionAndUpdatingIdleState.from;

  factory AppVersionAndUpdatingState.loading({
    required AppVersionAndUpdatingState previousState,
    required AppUpdatingLoadingStage stage,
    double progress,
  }) = _AppVersionAndUpdatingLoadingState;

  factory AppVersionAndUpdatingState.error({
    required AppVersionAndUpdatingState previousState,
    required AppUpdateException error,
  }) = _AppVersionAndUpdatingErrorState;

  bool get initialLoadCompleted => this is! _AppVersionAndUpdatingInitialState;

  AppUpdateException? get error => switch (this) {
    _AppVersionAndUpdatingErrorState(:final error) => error,
    _ => null,
  };

  AppUpdatingLoadingStage? get loadingStage => switch (this) {
    _AppVersionAndUpdatingLoadingState(:final stage) => stage,
    _ => null,
  };

  double get progress => switch (this) {
    _AppVersionAndUpdatingLoadingState(:final progress) => progress,
    _ => 0,
  };

  bool get isUpToDate => switch (this) {
    _AppVersionAndUpdatingIdleState(:final isUpToDate) => isUpToDate,
    _ => false,
  };

  bool get updating => switch (loadingStage) {
    AppUpdatingLoadingStage.downloading ||
    AppUpdatingLoadingStage.verifying ||
    AppUpdatingLoadingStage.installing => true,
    _ => false,
  };

  bool get showUpdateIndicator => availableUpdate != null || (error != null && error is! AppUpdateCheckException);

  @override
  String toString() =>
      'AppVersionAndUpdatingState(type: $runtimeType, version: $version, update: ${availableUpdate?.version}, '
      'stage: $loadingStage, attempt: ${operation.attemptId})';

  AppVersionAndUpdatingState copyWith({
    AppVersion? version,
    ValueData<AvailableAppUpdate>? availableUpdate,
    String? restoreServerId,
    ValueData<String>? updatedVersion,
    AppUpdatingOperationState? operation,
    double? progress,
  }) {
    final AppVersionAndUpdatingState updatedState = _AppVersionAndUpdatingIdleState(
      updatesSupported: updatesSupported,
      version: version ?? this.version,
      availableUpdate: availableUpdate == null ? this.availableUpdate : availableUpdate.value,
      restoreServerId: restoreServerId ?? this.restoreServerId,
      updatedVersion: updatedVersion == null ? this.updatedVersion : updatedVersion.value,
      operation: operation ?? this.operation,
    );

    return switch (this) {
      _AppVersionAndUpdatingInitialState() => _AppVersionAndUpdatingInitialState.from(updatedState),
      _AppVersionAndUpdatingIdleState(:final isUpToDate) => AppVersionAndUpdatingState.idle(
        previousState: updatedState,
        isUpToDate: isUpToDate,
      ),
      _AppVersionAndUpdatingLoadingState(:final stage) => AppVersionAndUpdatingState.loading(
        previousState: updatedState,
        stage: stage,
        progress: progress ?? this.progress,
      ),
      _AppVersionAndUpdatingErrorState(:final error) => AppVersionAndUpdatingState.error(
        previousState: updatedState,
        error: error,
      ),
    };
  }
}

final class _AppVersionAndUpdatingInitialState extends AppVersionAndUpdatingState {
  const _AppVersionAndUpdatingInitialState({
    required super.updatesSupported,
  }) : super._();

  _AppVersionAndUpdatingInitialState.from(
    super.previousState,
  ) : super._from();
}

final class _AppVersionAndUpdatingIdleState extends AppVersionAndUpdatingState {
  @override
  final bool isUpToDate;

  const _AppVersionAndUpdatingIdleState({
    required super.updatesSupported,
    super.version,
    super.availableUpdate,
    super.restoreServerId,
    super.updatedVersion,
    super.operation,
  }) : isUpToDate = false,
       super._();

  _AppVersionAndUpdatingIdleState.from({
    required AppVersionAndUpdatingState previousState,
    this.isUpToDate = false,
  }) : super._from(previousState);
}

final class _AppVersionAndUpdatingLoadingState extends AppVersionAndUpdatingState {
  final AppUpdatingLoadingStage stage;

  @override
  final double progress;

  _AppVersionAndUpdatingLoadingState({
    required AppVersionAndUpdatingState previousState,
    required this.stage,
    this.progress = 0,
  }) : super._from(previousState);
}

final class _AppVersionAndUpdatingErrorState extends AppVersionAndUpdatingState {
  @override
  final AppUpdateException error;

  _AppVersionAndUpdatingErrorState({
    required AppVersionAndUpdatingState previousState,
    required this.error,
  }) : super._from(previousState);
}
