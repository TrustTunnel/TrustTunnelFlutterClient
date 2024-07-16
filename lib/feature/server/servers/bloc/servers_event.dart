part of 'servers_bloc.dart';

@freezed
class ServersEvent with _$ServersEvent {
  const factory ServersEvent.init() = _Init;

  const factory ServersEvent.connectServer({
    required Object server,
  }) = _ConnectServer;

  const factory ServersEvent.disconnectServer({
    required Object server,
  }) = _DisconnectServer;
}
