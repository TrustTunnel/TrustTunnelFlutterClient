import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:vpn/data/model/routing_profile.dart';
import 'package:vpn/data/model/server.dart';
import 'package:vpn/data/model/vpn_log.dart';
import 'package:vpn/data/model/vpn_state.dart';
import 'package:vpn/data/repository/vpn_repository.dart';
import 'package:vpn/feature/vpn/domain/entity/log_controller.dart';
import 'package:vpn/feature/vpn/domain/entity/vpn_aspect.dart';
import 'package:vpn/feature/vpn/domain/entity/vpn_controller.dart';

typedef OnStartVpnCallback =
    Future<void> Function({
      required Server server,
      required RoutingProfile routingProfile,
      required List<String> excludedRoutes,
    });

class VpnScope extends StatefulWidget {
  final VpnRepository vpnRepository;
  final VpnState initialState;
  final Widget child;

  const VpnScope({
    required this.child,
    required this.vpnRepository,
    this.initialState = VpnState.disconnected,
    super.key,
  });

  @override
  State<VpnScope> createState() => _VpnScopeState();

  static VpnController? vpnControllerMaybeOf(BuildContext context, {bool listen = true}) =>
      _accessScope(context, listen: listen, aspect: VpnAspect.vpn);

  static VpnController vpnControllerOf(BuildContext context, {bool listen = true}) =>
      _accessScope(context, listen: listen, aspect: VpnAspect.vpn) ?? _notFoundInheritedWidgetOfExactType();

  static LogController? logsControllerMaybeOf(BuildContext context, {bool listen = true}) =>
      _accessScope(context, listen: listen, aspect: VpnAspect.logs);

  static LogController logsControllerOf(BuildContext context, {bool listen = true}) =>
      _accessScope(context, listen: listen, aspect: VpnAspect.logs) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedVpnScope? _accessScope(BuildContext context, {bool listen = true, VpnAspect? aspect}) => (listen
      ? InheritedModel.inheritFrom<_InheritedVpnScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedVpnScope>()?.widget as _InheritedVpnScope?);

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
    'Out of scope, not found inherited widget '
        'a _InheritedVpnScope of the exact type',
    'out_of_scope',
  );
}

class _VpnScopeState extends State<VpnScope> {
  late final ValueNotifier<VpnState> _stateNotifier;
  late final ValueNotifier<List<VpnLog>> _logsNotifier;
  late final StreamSubscription<VpnLog> _logStreamSub;
  static const _logLimit = 500;

  @override
  void initState() {
    super.initState();
    _stateNotifier = ValueNotifier(widget.initialState);
    _logsNotifier = ValueNotifier(<VpnLog>[]);
    widget.vpnRepository.listenToLogs().then((stream) => _logStreamSub = stream.listen(_onLogCollected));
  }

  StreamSubscription<VpnState>? _vpnStreamSub;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(
      [
        _stateNotifier,
        _logsNotifier,
      ],
    ),
    builder: (_, child) => _InheritedVpnScope(
      logs: _logsNotifier.value,
      state: _stateNotifier.value,
      onStart: _start,
      onStop: _stop,
      child: child!,
    ),
    child: widget.child,
  );

  Future<void> _start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) async {
    await _stop();

    final newServerStream = await widget.vpnRepository.startListenToStates(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
    );

    _vpnStreamSub = newServerStream.listen(_onVpnStateChanged);
  }

  Future<void> _stop() async {
    await widget.vpnRepository.stop();
    await _vpnStreamSub?.cancel();
    _stateNotifier.value = VpnState.disconnected;
    _vpnStreamSub = null;
  }

  void _onVpnStateChanged(VpnState state) {
    _stateNotifier.value = state;
  }

  void _onLogCollected(VpnLog log) {
    final limit = _logLimit;
    var trimmedList = _logsNotifier.value;
    if (_logsNotifier.value.length >= limit) {
      trimmedList = trimmedList.sublist(_logsNotifier.value.length - limit);
    }

    _logsNotifier.value = [...trimmedList, log];
  }

  @override
  void dispose() {
    _stop().ignore();
    _logStreamSub.cancel().ignore();
    _vpnStreamSub?.cancel().ignore();
    super.dispose();
  }
}

class _InheritedVpnScope extends InheritedModel<VpnAspect> implements VpnController, LogController {
  final AsyncCallback _onStop;
  final OnStartVpnCallback _onStart;

  @override
  final List<VpnLog> logs;

  @override
  final VpnState state;

  const _InheritedVpnScope({
    required OnStartVpnCallback onStart,
    required AsyncCallback onStop,
    required this.state,
    required this.logs,
    required super.child,
  }) : _onStart = onStart,
       _onStop = onStop;

  @override
  Future<void> start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) => _onStart(
    server: server,
    routingProfile: routingProfile,
    excludedRoutes: excludedRoutes,
  );

  @override
  Future<void> stop() => _onStop();

  @override
  bool updateShouldNotify(covariant _InheritedVpnScope oldWidget) =>
      _shouldNotifyLogController(oldWidget) || _shouldNotifyVpnController(oldWidget);

  @override
  bool updateShouldNotifyDependent(covariant _InheritedVpnScope oldWidget, Set<VpnAspect> dependencies) {
    if (dependencies.contains(VpnAspect.vpn) && _shouldNotifyVpnController(oldWidget)) {
      return true;
    }
    if (dependencies.contains(VpnAspect.logs) && _shouldNotifyLogController(oldWidget)) {
      return true;
    }

    return false;
  }

  bool _shouldNotifyVpnController(_InheritedVpnScope oldWidget) => oldWidget.state != state;

  bool _shouldNotifyLogController(_InheritedVpnScope oldWidget) => !listEquals(oldWidget.logs, logs);
}
