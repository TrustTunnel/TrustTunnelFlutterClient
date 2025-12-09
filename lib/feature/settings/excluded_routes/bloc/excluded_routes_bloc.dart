import 'dart:async';

import 'package:flutter/foundation.dart';
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
  }) : _settingsRepository = settingsRepository,
       super(const ExcludedRoutesState()) {
    on<ExcludedRoutesEvent>(
      (event, emit) async => await switch (event) {
        _Init() => _init(event, emit),
        _SaveExcludedRoutes() => _saveExcludedRoutes(event, emit),
        _DataChanged() => _dataChanged(event, emit),
      },
    );
  }

  Future<void> _init(
    _Init event,
    Emitter<ExcludedRoutesState> emit,
  ) async {
    emit(state.copyWith(loadingStatus: ExcludedRoutesLoadingStatus.initialLoading));
    try {
      final initialExcludedRoutes = await _settingsRepository.getExcludedRoutes();
      emit(
        state.copyWith(
          excludedRoutes: initialExcludedRoutes,
          initialExcludedRoutes: initialExcludedRoutes,
          loadingStatus: ExcludedRoutesLoadingStatus.idle,
        ),
      );
    } catch (e) {
      // TODO: [CRITICAL] Implement error handling here. There is no erros in figma.
      // Konstantin Gorynin <k.gorynin@adguard.com>, 26 August 2025
      rethrow;
    } finally {
      emit(state.copyWith(loadingStatus: ExcludedRoutesLoadingStatus.idle));
    }
  }

  Future<void> _saveExcludedRoutes(
    _SaveExcludedRoutes event,
    Emitter<ExcludedRoutesState> emit,
  ) async {
    await _settingsRepository.setExcludedRoutes(state.excludedRoutes);
    emit(state.copyWith(action: ExcludedRoutesAction.saved));
    emit(state.copyWith(action: ExcludedRoutesAction.none));
  }

  Future<void> _dataChanged(
    _DataChanged event,
    Emitter<ExcludedRoutesState> emit,
  ) async {
    print(event.excludedRoutes);
    emit(
      state.copyWith(
        excludedRoutes: event.excludedRoutes ?? state.excludedRoutes,
        hasInvalidRoutes: event.hasInvalidRoutes ?? state.hasInvalidRoutes,
      ),
    );
  }
}
