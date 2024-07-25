import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/repository/settings_repository.dart';
import 'package:vpn_plugin/platform_api.g.dart';

part 'query_log_bloc.freezed.dart';
part 'query_log_event.dart';
part 'query_log_state.dart';

class QueryLogBloc extends Bloc<QueryLogEvent, QueryLogState> {
  final SettingsRepository _settingsRepository;

  QueryLogBloc({
    required SettingsRepository settingsRepository,
  })  : _settingsRepository = settingsRepository,
        super(const QueryLogState()) {
    on<_Init>(_init);
  }

  void _init(
    _Init event,
    Emitter<QueryLogState> emit,
  ) async =>
      emit(
        state.copyWith(
          logs: await _settingsRepository.getAllRequests(),
        ),
      );
}
