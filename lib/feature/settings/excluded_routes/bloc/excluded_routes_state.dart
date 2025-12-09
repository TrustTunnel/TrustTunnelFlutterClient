part of 'excluded_routes_bloc.dart';

@freezed
abstract class ExcludedRoutesState with _$ExcludedRoutesState {
  const factory ExcludedRoutesState({
    @Default([]) List<String> excludedRoutes,
    @Default([]) List<String> initialExcludedRoutes,
    @Default(ExcludedRoutesAction.none) ExcludedRoutesAction action,
    @Default(ExcludedRoutesLoadingStatus.initialLoading) ExcludedRoutesLoadingStatus loadingStatus,
    @Default(false) bool hasInvalidRoutes,
  }) = _ExcludedRoutesState;

  const ExcludedRoutesState._();

  bool get isLoading => loadingStatus != ExcludedRoutesLoadingStatus.idle;

  bool get hasChanges => !listEquals(excludedRoutes, initialExcludedRoutes);

  bool get isValid => !hasInvalidRoutes || excludedRoutes.where((element) => element.trim().isNotEmpty).isEmpty;
}

enum ExcludedRoutesLoadingStatus {
  initialLoading,
  loading,
  idle,
}

enum ExcludedRoutesAction {
  saved,
  none,
}
