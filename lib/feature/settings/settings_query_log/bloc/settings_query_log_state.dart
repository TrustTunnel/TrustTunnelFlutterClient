part of 'settings_query_log_bloc.dart';

@freezed
class SettingsQueryLogState with _$SettingsQueryLogState {
  const SettingsQueryLogState._();

  const factory SettingsQueryLogState({
    @Default([]) List<QueryLogData> logs,
  }) = _SettingsQueryLogState;
}
