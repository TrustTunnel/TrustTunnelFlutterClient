import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/server/server_sharing/controller/server_sharing_controller.dart';
import 'package:trusttunnel/feature/server/server_sharing/controller/server_sharing_state.dart';
import 'package:trusttunnel/feature/server/server_sharing/widgets/scope/server_sharing_scope_controller.dart';

class ServerSharingScope extends StatefulWidget {
  final Widget child;

  const ServerSharingScope({required this.child, super.key});

  static ServerSharingScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
  }) => _InheritedServerSharingScope.controllerOf(context, listen: listen);

  @override
  State<ServerSharingScope> createState() => _ServerSharingScopeState();
}

class _ServerSharingScopeState extends State<ServerSharingScope> {
  late final ServerSharingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ServerSharingController(repository: context.repositoryFactory.deepLinkRepository);
  }

  @override
  Widget build(BuildContext context) => StateConsumer<ServerSharingController, ServerSharingState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedServerSharingScope(
      loading: state.loading,
      copyLink: _controller.copyLink,
      share: _controller.share,
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedServerSharingScope extends InheritedWidget implements ServerSharingScopeController {
  @override
  final bool loading;

  @override
  final void Function({
    required ServerData server,
    VoidCallback? onCopied,
    VoidCallback? onError,
  })
  copyLink;

  @override
  final void Function({
    required ServerData server,
    VoidCallback? onError,
  })
  share;

  const _InheritedServerSharingScope({
    required this.loading,
    required this.copyLink,
    required this.share,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedServerSharingScope oldWidget) => loading != oldWidget.loading;

  static _InheritedServerSharingScope controllerOf(
    BuildContext context, {
    bool listen = true,
  }) => _inheritFrom(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedServerSharingScope? _inheritFrom(
    BuildContext context, {
    bool listen = true,
  }) => (listen
      ? context.dependOnInheritedWidgetOfExactType<_InheritedServerSharingScope>()
      : context.getElementForInheritedWidgetOfExactType<_InheritedServerSharingScope>()?.widget
            as _InheritedServerSharingScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedWidget>() => throw ArgumentError(
    'Inherited widget out of scope and not found of $T exact type',
    'out_of_scope',
  );
}
