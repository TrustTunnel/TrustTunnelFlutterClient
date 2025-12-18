import 'package:trusttunnel/common/error/model/presentation_error.dart';

/// {@template ExcludedRoutes_state}
/// State representation for ExcludedRoutes-related operations.
/// {@endtemplate}
sealed class ExcludedRoutesState {
  final List<String> excludedRoutes;
  final List<String> initialExcludedRoutes;
  final bool hasInvalidRoutes;

  const ExcludedRoutesState._({
    required this.excludedRoutes,
    required this.initialExcludedRoutes,
    required this.hasInvalidRoutes,
  });

  const factory ExcludedRoutesState.initial() = _InitialExcludedRoutesState;

  /// Initial / idle state
  const factory ExcludedRoutesState.idle({
    required List<String> excludedRoutes,
    required List<String> initialExcludedRoutes,
    required bool hasInvalidRoutes,
  }) = _IdleExcludedRoutesState;

  /// Loading state
  const factory ExcludedRoutesState.loading({
    required List<String> excludedRoutes,
    required List<String> initialExcludedRoutes,
    required bool hasInvalidRoutes,
  }) = _LoadingExcludedRoutesState;

  /// Error state
  const factory ExcludedRoutesState.exception({
    required List<String> excludedRoutes,
    required List<String> initialExcludedRoutes,
    required bool hasInvalidRoutes,
    required PresentationError exception,
  }) = _ErrorExcludedRoutesState;

  PresentationError? get error =>
      this is _ErrorExcludedRoutesState ? (this as _ErrorExcludedRoutesState).exception : null;

  bool get loading => this is _LoadingExcludedRoutesState;
}

final class _IdleExcludedRoutesState extends ExcludedRoutesState {
  const _IdleExcludedRoutesState({
    required super.excludedRoutes,
    required super.initialExcludedRoutes,
    required super.hasInvalidRoutes,
  }) : super._();
}

final class _InitialExcludedRoutesState extends _IdleExcludedRoutesState {
  const _InitialExcludedRoutesState()
    : super(
        excludedRoutes: const [],
        initialExcludedRoutes: const [],
        hasInvalidRoutes: false,
      );
}

final class _LoadingExcludedRoutesState extends ExcludedRoutesState {
  const _LoadingExcludedRoutesState({
    required super.excludedRoutes,
    required super.initialExcludedRoutes,
    required super.hasInvalidRoutes,
  }) : super._();
}

final class _ErrorExcludedRoutesState extends ExcludedRoutesState {
  final PresentationError exception;

  const _ErrorExcludedRoutesState({
    required super.excludedRoutes,
    required super.initialExcludedRoutes,
    required super.hasInvalidRoutes,
    required this.exception,
  }) : super._();
}
