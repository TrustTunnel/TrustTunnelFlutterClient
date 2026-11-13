import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/installed_app.dart';

/// {@template excluded_apps_state}
/// State representation for the per-app exclusion feature.
/// {@endtemplate}
sealed class ExcludedAppsState {
  /// Currently selected (checked) package names — the editable buffer.
  final List<String> excludedApps;

  /// Snapshot of persisted packages at fetch time (for change detection).
  final List<String> initialExcludedApps;

  /// Applications installed on the device (for the selection list).
  final List<InstalledApp> installedApps;

  /// Whether the installed applications list is being loaded.
  final bool appsLoading;

  const ExcludedAppsState._({
    required this.excludedApps,
    required this.initialExcludedApps,
    required this.installedApps,
    required this.appsLoading,
  });

  const factory ExcludedAppsState.initial() = _InitialExcludedAppsState;

  /// Initial / idle state
  const factory ExcludedAppsState.idle({
    required List<String> excludedApps,
    required List<String> initialExcludedApps,
    required List<InstalledApp> installedApps,
    required bool appsLoading,
  }) = _IdleExcludedAppsState;

  /// Loading state
  const factory ExcludedAppsState.loading({
    required List<String> excludedApps,
    required List<String> initialExcludedApps,
    required List<InstalledApp> installedApps,
    required bool appsLoading,
  }) = _LoadingExcludedAppsState;

  /// Error state
  const factory ExcludedAppsState.exception({
    required List<String> excludedApps,
    required List<String> initialExcludedApps,
    required List<InstalledApp> installedApps,
    required bool appsLoading,
    required PresentationException exception,
  }) = _ErrorExcludedAppsState;

  PresentationException? get error =>
      this is _ErrorExcludedAppsState ? (this as _ErrorExcludedAppsState).exception : null;

  bool get loading => this is _LoadingExcludedAppsState;

  @override
  String toString() =>
      'ExcludedAppsState(type: $runtimeType, excludedApps: ${excludedApps.length}, '
      'initialExcludedApps: ${initialExcludedApps.length}, '
      'installedApps: ${installedApps.length}, appsLoading: $appsLoading, loading: $loading)';
}

final class _IdleExcludedAppsState extends ExcludedAppsState {
  const _IdleExcludedAppsState({
    required super.excludedApps,
    required super.initialExcludedApps,
    required super.installedApps,
    required super.appsLoading,
  }) : super._();
}

final class _InitialExcludedAppsState extends _IdleExcludedAppsState {
  const _InitialExcludedAppsState()
    : super(
        excludedApps: const [],
        initialExcludedApps: const [],
        installedApps: const [],
        appsLoading: false,
      );
}

final class _LoadingExcludedAppsState extends ExcludedAppsState {
  const _LoadingExcludedAppsState({
    required super.excludedApps,
    required super.initialExcludedApps,
    required super.installedApps,
    required super.appsLoading,
  }) : super._();
}

final class _ErrorExcludedAppsState extends ExcludedAppsState {
  final PresentationException exception;

  const _ErrorExcludedAppsState({
    required super.excludedApps,
    required super.initialExcludedApps,
    required super.installedApps,
    required super.appsLoading,
    required this.exception,
  }) : super._();
}
