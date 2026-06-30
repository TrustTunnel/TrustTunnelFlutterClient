import 'package:collection/collection.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/server.dart';

/// {@template Servers_state}
/// State representation for Servers-related operations.
/// {@endtemplate}
sealed class ServersState {
  final List<Server> servers;

  const ServersState._({
    required this.servers,
  });

  const factory ServersState.initial() = _InitialServersState;

  /// Initial / idle state
  const factory ServersState.idle({
    required List<Server> servers,
  }) = _IdleServersState;

  /// Loading state
  const factory ServersState.loading({
    required List<Server> servers,
  }) = _LoadingServersState;

  /// Error state
  const factory ServersState.exception({
    required List<Server> servers,
    required PresentationException exception,
  }) = _ErrorServersState;

  Server? get selectedServer => servers.firstWhereOrNull((e) => e.serverData.selected);

  PresentationException? get error => this is _ErrorServersState ? (this as _ErrorServersState).error : null;

  bool get loading => this is _LoadingServersState;

  @override
  String toString() =>
      'ServersState(type: $runtimeType, '
      'count: ${servers.length}, selectedId: ${selectedServer?.id}, loading: $loading)';
}

final class _IdleServersState extends ServersState {
  const _IdleServersState({
    required super.servers,
  }) : super._();
}

final class _InitialServersState extends _IdleServersState {
  const _InitialServersState()
    : super(
        servers: const [],
      );
}

final class _LoadingServersState extends ServersState {
  const _LoadingServersState({
    required super.servers,
  }) : super._();
}

final class _ErrorServersState extends ServersState {
  final PresentationException exception;

  const _ErrorServersState({
    required super.servers,
    required this.exception,
  }) : super._();
}
