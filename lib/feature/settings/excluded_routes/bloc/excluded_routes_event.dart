part of 'excluded_routes_bloc.dart';

@freezed
sealed class ExcludedRoutesEvent with _$ExcludedRoutesEvent {
  const factory ExcludedRoutesEvent.init() = _Init;

  const factory ExcludedRoutesEvent.dataChanged({
    List<String>? excludedRoutes,
    bool? hasInvalidRoutes,
  }) = _DataChanged;

  const factory ExcludedRoutesEvent.saveExcludedRoutes() = _SaveExcludedRoutes;
}
