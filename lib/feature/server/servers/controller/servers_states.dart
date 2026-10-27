import 'package:collection/collection.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/server.dart';

/// {@template Servers_state}
/// State representation for Servers-related operations.
/// {@endtemplate}
sealed class ServersState {
  final List<Server> servers;

  /// Choices that are queued or still saving the DB selection or launch target.
  final int pendingSelections;

  const ServersState._({
    required this.servers,
    this.pendingSelections = 0,
  }) : assert(pendingSelections >= 0);

  const factory ServersState.initial() = _InitialServersState;

  /// Initial / idle state
  const factory ServersState.idle({
    required List<Server> servers,
    int pendingSelections,
  }) = _IdleServersState;

  /// Loading state
  const factory ServersState.loading({
    required List<Server> servers,
    int pendingSelections,
  }) = _LoadingServersState;

  /// Error state
  const factory ServersState.exception({
    required List<Server> servers,
    required PresentationException exception,
    int pendingSelections,
  }) = _ErrorServersState;

  Server? get selectedServer => servers.firstWhereOrNull((e) => e.serverData.selected);

  PresentationException? get error => this is _ErrorServersState ? (this as _ErrorServersState).exception : null;

  bool get loading => this is _LoadingServersState || pendingSelections > 0;

  @override
  String toString() =>
      'ServersState(type: $runtimeType, '
      'count: ${servers.length}, selectedId: ${selectedServer?.id}, loading: $loading, '
      'pendingSelections: $pendingSelections)';

  /// Updates data without changing the current operation status or clearing its error.
  ServersState copyWith({
    List<Server>? servers,
    int? pendingSelections,
  }) => switch (this) {
    _LoadingServersState() => ServersState.loading(
      servers: servers ?? this.servers,
      pendingSelections: pendingSelections ?? this.pendingSelections,
    ),
    _ErrorServersState(:final exception) => ServersState.exception(
      servers: servers ?? this.servers,
      exception: exception,
      pendingSelections: pendingSelections ?? this.pendingSelections,
    ),
    _IdleServersState() => ServersState.idle(
      servers: servers ?? this.servers,
      pendingSelections: pendingSelections ?? this.pendingSelections,
    ),
  };
}

final class _IdleServersState extends ServersState {
  const _IdleServersState({
    required super.servers,
    super.pendingSelections,
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
    super.pendingSelections,
  }) : super._();
}

final class _ErrorServersState extends ServersState {
  final PresentationException exception;

  const _ErrorServersState({
    required super.servers,
    required this.exception,
    super.pendingSelections,
  }) : super._();
}
