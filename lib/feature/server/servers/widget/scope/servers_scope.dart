import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/feature/server/servers/controller/servers_controller.dart';
import 'package:trusttunnel/feature/server/servers/controller/servers_states.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';

/// {@template products_scope_template}
/// Provides Products controller to the widget tree
/// {@endtemplate}
class ServersScope extends StatefulWidget {
  final Widget child;

  /// {@macro products_scope_template}
  const ServersScope({
    required this.child,
    super.key,
  });

  /// Get the controller from context
  static ServersScopeController controllerOf(BuildContext context, {bool listen = true, ServersScopeAspect? aspect}) =>
      _InheritedServersScope.serversControllerOf(context, listen: listen, aspect: aspect);

  @override
  State<ServersScope> createState() => _ServersScopeState();
}

class _ServersScopeState extends State<ServersScope> {
  late final ServersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ServersController(repository: context.repositoryFactory.serverRepository);
    _controller.fetchServers();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<ServersController, ServersState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedServersScope(
      state: state,
      pickServer: _controller.selectServer,
      fetchServers: _controller.fetchServers,
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedServersScope extends InheritedModel<ServersScopeAspect> implements ServersScopeController {
  final ServersState _state;

  @override
  final void Function(int? serverId) pickServer;

  @override
  final void Function() fetchServers;

  const _InheritedServersScope({
    required ServersState state,
    required this.pickServer,
    required this.fetchServers,
    required super.child,
  }) : _state = state;

  @override
  List<Server> get servers => [..._state.servers];

  @override
  Server? get selectedServer => _state.servers.firstWhereOrNull((server) => server.id == _state.selectedServer);

  @override
  PresentationError? get error => _state.error;

  @override
  bool get loading => _state.loading;

  @override
  bool updateShouldNotify(_InheritedServersScope oldWidget) => _state != oldWidget._state;

  static _InheritedServersScope serversControllerOf(
    BuildContext context, {
    bool listen = true,
    ServersScopeAspect? aspect,
  }) => _productsScope(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedServersScope oldWidget,
    Set<ServersScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);
    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        ServersScopeAspect.loading => loading != oldWidget.loading,
        ServersScopeAspect.exception => error != oldWidget.error,
        ServersScopeAspect.servers => !listEquals(servers, oldWidget.servers),
        ServersScopeAspect.selectedServer => selectedServer != oldWidget.selectedServer,
      };

      if (hasAnyChanges) {
        return hasAnyChanges;
      }
    }

    return false;
  }

  static _InheritedServersScope? _productsScope(
    BuildContext context, {
    bool listen = true,
    ServersScopeAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedServersScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedServersScope>()?.widget as _InheritedServersScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<ServersScopeAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
