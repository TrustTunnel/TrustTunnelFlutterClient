part of 'excluded_routes_bloc.dart';

@freezed
sealed class ExcludedRoutesState with _$ExcludedRoutesState {
  const ExcludedRoutesState._();

  const factory ExcludedRoutesState({
    @Default('') String data,
    @Default('') String initialData,
    @Default(ExcludedRoutesAction.none) ExcludedRoutesAction action,
    @Default(ExcludedRoutesLoadingStatus.initialLoading) ExcludedRoutesLoadingStatus loadingStatus,
  }) = _ExcludedRoutesState;

  bool get wasChanged => data != initialData;
}

enum ExcludedRoutesLoadingStatus {
  initialLoading,
  idle,
}

enum ExcludedRoutesAction {
  saved,
  none,
}
