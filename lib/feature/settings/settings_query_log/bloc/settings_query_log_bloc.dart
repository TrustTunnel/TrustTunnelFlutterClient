import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/model/network_protocol.dart';
import 'package:vpn/data/model/routing_mode.dart';
import 'package:vpn/feature/settings/settings_query_log/data/query_log_data.dart';

part 'settings_query_log_bloc.freezed.dart';
part 'settings_query_log_event.dart';
part 'settings_query_log_state.dart';

class SettingsQueryLogBloc
    extends Bloc<SettingsQueryLogEvent, SettingsQueryLogState> {
  SettingsQueryLogBloc() : super(const SettingsQueryLogState()) {
    on<_Init>(_init);
  }

  void _init(
    _Init event,
    Emitter<SettingsQueryLogState> emit,
  ) =>
      emit(
        state.copyWith(
          logs: List<QueryLogData>.generate(
            100,
            (i) => QueryLogData(
              dateTime: DateTime.now(),
              routingMode: RoutingMode.bypass,
              originIpAddress: '172.20.2.13:53446',
              vpnServerIpAddress: '17.248.209.66:443',
              ipAddressDomain: 'gateway.icloud.com',
              networkProtocol: NetworkProtocol.tcp,
            ),
          ),
        ),
      );
}
