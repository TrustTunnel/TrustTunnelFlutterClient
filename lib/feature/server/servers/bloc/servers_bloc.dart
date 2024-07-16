import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
          serverList: List.filled(
            10,
            Object(),
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
