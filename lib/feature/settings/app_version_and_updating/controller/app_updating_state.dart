import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

enum AppUpdatingLoadingStage {
  downloading,
  verifying,
  installing,
}

@immutable
sealed class AppUpdatingState {
  final bool updatesSupported;
  final AppVersion? version;
  final AvailableAppUpdate? update;
  final String? restoreServerId;
  final String? updatedVersion;

  /// 1. Preparation starts with a new revision.
  /// 2. Cancellation or another attempt changes the revision.
  /// 3. Events from the old preparation cannot change state or launch setup.
  /// Release checks record the revision too, so an update can invalidate their late results.
  final int operationRevision;

  /// 1. Setup receives this ID when it starts.
  /// 2. Before exit, the app saves the ID with the update and VPN server.
  /// 3. After restart, the ID identifies the result that belongs to this installation.
  final String? installationOperationId;

  const AppUpdatingState._({
    required this.updatesSupported,
    this.version,
    this.update,
    this.restoreServerId,
    this.updatedVersion,
    this.operationRevision = 0,
    this.installationOperationId,
  });

  AppUpdatingState._from(AppUpdatingState previousState)
    : updatesSupported = previousState.updatesSupported,
      version = previousState.version,
      update = previousState.update,
      restoreServerId = previousState.restoreServerId,
      updatedVersion = previousState.updatedVersion,
      operationRevision = previousState.operationRevision,
      installationOperationId = previousState.installationOperationId;

  const factory AppUpdatingState.initial({required bool updatesSupported}) = _AppUpdatingInitialState;

  factory AppUpdatingState.idle({required AppUpdatingState previousState}) = _AppUpdatingIdleState.from;

  factory AppUpdatingState.loading({
    required AppUpdatingState previousState,
    required AppUpdatingLoadingStage stage,
    double progress,
  }) = _AppUpdatingLoadingState;

  factory AppUpdatingState.error({
    required AppUpdatingState previousState,
    required AppUpdateException error,
  }) = _AppUpdatingErrorState;

  bool get initialLoadCompleted => this is! _AppUpdatingInitialState;

  AppUpdateException? get error => switch (this) {
    _AppUpdatingErrorState(:final error) => error,
    _ => null,
  };

  AppUpdatingLoadingStage? get loadingStage => switch (this) {
    _AppUpdatingLoadingState(:final stage) => stage,
    _ => null,
  };

  double get progress => switch (this) {
    _AppUpdatingLoadingState(:final progress) => progress,
    _ => 0,
  };

  bool get updating => switch (loadingStage) {
    AppUpdatingLoadingStage.downloading ||
    AppUpdatingLoadingStage.verifying ||
    AppUpdatingLoadingStage.installing => true,
    _ => false,
  };

  bool get canCancelDownload =>
      loadingStage == AppUpdatingLoadingStage.downloading || loadingStage == AppUpdatingLoadingStage.verifying;

  @override
  String toString() =>
      'AppUpdatingState(type: $runtimeType, version: $version, update: ${update?.version}, '
      'stage: $loadingStage)';

  AppUpdatingState copyWith({
    AppVersion? version,
    ValueData<AvailableAppUpdate>? update,
    String? restoreServerId,
    ValueData<String>? updatedVersion,
    int? operationRevision,
    ValueData<String>? installationOperationId,
    double? progress,
  }) {
    final AppUpdatingState updatedState = _AppUpdatingIdleState(
      updatesSupported: updatesSupported,
      version: version ?? this.version,
      update: update == null ? this.update : update.value,
      restoreServerId: restoreServerId ?? this.restoreServerId,
      updatedVersion: updatedVersion == null ? this.updatedVersion : updatedVersion.value,
      operationRevision: operationRevision ?? this.operationRevision,
      installationOperationId: installationOperationId == null
          ? this.installationOperationId
          : installationOperationId.value,
    );

    return switch (this) {
      _AppUpdatingInitialState() => _AppUpdatingInitialState.from(updatedState),
      _AppUpdatingIdleState() => AppUpdatingState.idle(previousState: updatedState),
      _AppUpdatingLoadingState(:final stage) => AppUpdatingState.loading(
        previousState: updatedState,
        stage: stage,
        progress: progress ?? this.progress,
      ),
      _AppUpdatingErrorState(:final error) => AppUpdatingState.error(
        previousState: updatedState,
        error: error,
      ),
    };
  }
}

final class _AppUpdatingInitialState extends AppUpdatingState {
  const _AppUpdatingInitialState({
    required super.updatesSupported,
  }) : super._();

  _AppUpdatingInitialState.from(
    super.previousState,
  ) : super._from();
}

final class _AppUpdatingIdleState extends AppUpdatingState {
  const _AppUpdatingIdleState({
    required super.updatesSupported,
    super.version,
    super.update,
    super.restoreServerId,
    super.updatedVersion,
    super.operationRevision,
    super.installationOperationId,
  }) : super._();

  _AppUpdatingIdleState.from({
    required AppUpdatingState previousState,
  }) : super._from(previousState);
}

final class _AppUpdatingLoadingState extends AppUpdatingState {
  final AppUpdatingLoadingStage stage;

  @override
  final double progress;

  _AppUpdatingLoadingState({
    required AppUpdatingState previousState,
    required this.stage,
    this.progress = 0,
  }) : super._from(previousState);
}

final class _AppUpdatingErrorState extends AppUpdatingState {
  @override
  final AppUpdateException error;

  _AppUpdatingErrorState({
    required AppUpdatingState previousState,
    required this.error,
  }) : super._from(previousState);
}
