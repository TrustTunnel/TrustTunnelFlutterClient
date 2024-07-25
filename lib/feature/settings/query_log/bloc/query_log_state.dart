part of 'query_log_bloc.dart';

@freezed
class QueryLogState with _$QueryLogState {
  const QueryLogState._();

  const factory QueryLogState({
    @Default([]) List<VpnRequest> logs,
  }) = _QueryLogState;
}
