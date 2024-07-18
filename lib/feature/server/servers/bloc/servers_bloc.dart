import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/model/server.dart';
import 'package:vpn/data/model/vpn_protocol.dart';

part 'servers_bloc.freezed.dart';
part 'servers_event.dart';
part 'servers_state.dart';

class ServersBloc extends Bloc<ServersEvent, ServersState> {
  ServersBloc() : super(const ServersState()) {
    on<_Init>(_init);
    on<_ConnectServer>(_connectServer);
    on<_DisconnectServer>(_disconnectServer);
  }

  void _init(
    _Init event,
    Emitter<ServersState> emit,
  ) =>
      emit(
        state.copyWith(
          serverList: List.generate(
            10,
            (i) => Server(
              id: i,
              name: 'Server $i',
              ipAddress: '$i.$i.$i.$i',
              domain: '$i.$i.$i.$i',
              login: 'login-$i',
              password: 'password-$i',
              vpnProtocol: VpnProtocol.http2,
              routingProfileId: 0,
              dnsServers: [],
            ),
          ),
        ),
      );

  void _connectServer(
    _ConnectServer event,
    Emitter<ServersState> emit,
  ) {
    // TODO implement server connection
  }

  void _disconnectServer(
    _DisconnectServer event,
    Emitter<ServersState> emit,
  ) {
    // TODO implement server disconnection
  }
}
