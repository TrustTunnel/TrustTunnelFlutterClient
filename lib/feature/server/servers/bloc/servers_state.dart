part of 'servers_bloc.dart';

@freezed
class ServersState with _$ServersState {
  const ServersState._();

  const factory ServersState({
    @Default([]) List<Server> serverList,
  }) = _ServersState;
}
