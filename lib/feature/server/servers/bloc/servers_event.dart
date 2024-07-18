part of 'servers_bloc.dart';

@freezed
class ServersEvent with _$ServersEvent {
  const factory ServersEvent.init() = _Init;

  const factory ServersEvent.connectServer({
    required Server server,
  }) = _ConnectServer;

  const factory ServersEvent.disconnectServer({
    required Server server,
  }) = _DisconnectServer;
}
