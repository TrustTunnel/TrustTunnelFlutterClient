import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/feature/server/servers/controller/servers_controller.dart';
import 'package:trusttunnel/feature/server/servers/controller/servers_states.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_controller.dart';

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
  static ServersScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    ServersScopeAspect? aspect,
  }) => _InheritedServersScope.serversControllerOf(
    context,
    listen: listen,
    aspect: aspect,
  ).controller;

  @override
  State<ServersScope> createState() => _ServersScopeState();
}

class _ServersScopeState extends State<ServersScope> implements ServersScopeController {
  late final ServersController _controller;
  late final AutoConnectOnLaunchSettingsController _autoConnectOnLaunchSettingsController;

  @override
  List<Server> get servers => [..._controller.state.servers];

  @override
  Server? get selectedServer => _controller.state.selectedServer;

  @override
  PresentationException? get error => _controller.state.error;

  @override
  bool get loading => _controller.state.loading;

  @override
  void Function() get fetchServers => _controller.fetchServers;

  @override
  void Function(String? serverId) get pickServer => _selectServer;

  @override
  void initState() {
    super.initState();

    final repositoryFactory = context.repositoryFactory;
    _controller = ServersController(repository: repositoryFactory.serverRepository);
    _autoConnectOnLaunchSettingsController = AutoConnectOnLaunchSettingsController(
      repository: repositoryFactory.autoConnectOnLaunchSettingsRepository,
    );

    _controller.fetchServers();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<ServersController, ServersState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedServersScope(
      controller: this,
      state: state,
      child: widget.child,
    ),
  );

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _controller.removeListener(listener);

  void _selectServer(String? serverId) {
    _autoConnectOnLaunchSettingsController.setLastServerId(serverId);
    _controller.selectServer(serverId);
  }

  @override
  void dispose() {
    _autoConnectOnLaunchSettingsController.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedServersScope extends InheritedModel<ServersScopeAspect> {
  final ServersScopeController controller;

  final ServersState _state;

  const _InheritedServersScope({
    required this.controller,
    required this._state,
    required super.child,
  });

  List<Server> get servers => [..._state.servers];

  Server? get selectedServer => _state.selectedServer;

  PresentationException? get error => _state.error;

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
