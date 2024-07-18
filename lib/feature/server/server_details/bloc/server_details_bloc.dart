import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/model/vpn_protocol.dart';
import 'package:vpn/feature/server/server_details/data/server_details_data.dart';

part 'server_details_bloc.freezed.dart';
part 'server_details_event.dart';
part 'server_details_state.dart';

class ServerDetailsBloc extends Bloc<ServerDetailsEvent, ServerDetailsState> {
  ServerDetailsBloc({int? serverId})
      : super(ServerDetailsState(serverId: serverId)) {
    on<_Init>(_init);
    on<_DataChanged>(_dataChanged);
    on<_AddServer>(_addServer);
    on<_ChangeLoadingStatus>(_changeLoadingStatus);
  }

  Future<void> _init(
    _Init event,
    Emitter<ServerDetailsState> emit,
  ) async {
    if (state.serverId == null) {
      add(
        const ServerDetailsEvent.changeLoadingStatus(
          loadingStatus: ServerDetailsLoadingStatus.idle,
        ),
      );
      return;
    }
    // async request imitation  
    await Future.delayed(
      const Duration(milliseconds: 100),
    );
    // TODO fetch server details by id
    ServerDetailsData initialData = ServerDetailsData(
      serverName: 'server ${state.serverId}',
      vpnServerIpAddress: '1.1.1.1',
      ipAddressDomain: '1.1.1.1',
      username: 'username',
      password: 'password',
      protocol: VpnProtocol.http2,
      // TODO add routingProfile
      // routingProfile: '',
      dnsServers: ['1.1.1.1', '2.2.2.2'],
    );

    emit(
      state.copyWith(
        data: initialData,
        initialData: initialData,
        loadingStatus: ServerDetailsLoadingStatus.idle,
      ),
    );
  }

  void _dataChanged(
    _DataChanged event,
    Emitter<ServerDetailsState> emit,
  ) {
    final serverName = event.serverName ?? state.data.serverName;
    final vpnServerIpAddress =
        event.vpnServerIpAddress ?? state.data.vpnServerIpAddress;
    final ipAddressDomain = event.ipAddressDomain ?? state.data.ipAddressDomain;
    final username = event.username ?? state.data.username;
    final password = event.password ?? state.data.password;
    final protocol = event.protocol ?? state.data.protocol;
    final dnsServers = event.dnsServers ?? state.data.dnsServers;

    emit(
      state.copyWith(
        data: state.data.copyWith(
          serverName: serverName,
          vpnServerIpAddress: vpnServerIpAddress,
          ipAddressDomain: ipAddressDomain,
          username: username,
          password: password,
          protocol: protocol,
          dnsServers: dnsServers,
        ),
      ),
    );
  }

  void _addServer(
    _AddServer event,
    Emitter<ServerDetailsState> emit,
  ) {
    // TODO add server
  }

  void _changeLoadingStatus(
    _ChangeLoadingStatus event,
    Emitter<ServerDetailsState> emit,
  ) =>
      emit(
        state.copyWith(
          loadingStatus: event.loadingStatus,
        ),
      );
}
