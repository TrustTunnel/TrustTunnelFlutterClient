import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/repository/settings_repository.dart';

part 'excluded_routes_bloc.freezed.dart';
part 'excluded_routes_event.dart';
part 'excluded_routes_state.dart';

class ExcludedRoutesBloc extends Bloc<ExcludedRoutesEvent, ExcludedRoutesState> {
  final SettingsRepository _settingsRepository;

  ExcludedRoutesBloc({
    required SettingsRepository settingsRepository,
  })  : _settingsRepository = settingsRepository,
        super(const ExcludedRoutesState()) {
    on<_Init>(_init);
    on<_DataChanged>(_dataChanged);
    on<_SaveExcludedRoutes>(_saveExcludedRoutes);
  }

  Future<void> _init(
    _Init event,
    Emitter<ExcludedRoutesState> emit,
  ) async {
    final String excludedRoutes = await _settingsRepository.getExcludedRoutes();
    emit(
      state.copyWith(
        initialData: excludedRoutes,
        data: excludedRoutes,
        loadingStatus: ExcludedRoutesLoadingStatus.idle,
      ),
    );
  }

  void _dataChanged(
    _DataChanged event,
    Emitter<ExcludedRoutesState> emit,
  ) =>
      emit(state.copyWith(data: event.excludedRoutes));

  void _saveExcludedRoutes(
    _SaveExcludedRoutes event,
    Emitter<ExcludedRoutesState> emit,
  ) async {
    await _settingsRepository.setExcludedRoutes(state.data);

    emit(state.copyWith(action: ExcludedRoutesAction.saved));
    emit(state.copyWith(action: ExcludedRoutesAction.none));
  }
}
