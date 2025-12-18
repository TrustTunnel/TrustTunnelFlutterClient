import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/data/repository/vpn_repository.dart';
import 'package:trusttunnel/feature/vpn/models/log_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_aspect.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';

/// {@template vpn_scope_on_start_callback}
/// Signature of the "start VPN" operation used by [VpnScope].
///
/// The callback starts a VPN session for the given [server] and [routingProfile]
/// and applies [excludedRoutes] (typically CIDR ranges) as part of routing
/// configuration.
///
/// The concrete behavior depends on the platform/backend implementation behind
/// the repository, but the callback is expected to complete only after the
/// start request has been handed off to the backend (not necessarily after a
/// successful connection).
/// {@endtemplate}
typedef OnStartVpnCallback =
    Future<void> Function({
      required Server server,
      required RoutingProfile routingProfile,
      required List<String> excludedRoutes,
    });

/// {@template vpn_scope}
/// Provides access to VPN state, logs, and control operations to a widget subtree.
///
/// `VpnScope` is an app-level scope built on top of [InheritedModel] that exposes
/// two "controllers" to descendants:
/// - a [VpnController] (VPN lifecycle + current [VpnState])
/// - a [LogController] (collected [VpnLog] entries)
///
/// Descendants obtain these controllers using:
/// - [VpnScope.vpnControllerOf] / [VpnScope.vpnControllerMaybeOf]
/// - [VpnScope.logsControllerOf] / [VpnScope.logsControllerMaybeOf]
///
/// ## How updates and rebuilds work
/// Internally, this scope uses [InheritedModel] with [VpnAspect] to support
/// aspect-based subscriptions:
/// - Consumers that subscribe to [VpnAspect.vpn] rebuild only when [VpnState]
///   changes.
/// - Consumers that subscribe to [VpnAspect.logs] rebuild only when the log list
///   changes.
/// - If a consumer requests both aspects, it may rebuild on either change.
///
/// To control whether your widget rebuilds:
/// - Pass `listen: true` (default) to subscribe and rebuild on updates.
/// - Pass `listen: false` to read the controller without subscribing.
///
/// ## VPN lifecycle and state
/// `VpnScope` maintains a current [VpnState] value and updates it by subscribing
/// to a state stream produced by [VpnRepository.startListenToStates].
///
/// Calling [VpnController.start] will:
/// 1) stop any existing session (by calling [VpnController.stop]),
/// 2) start listening to the new state stream,
/// 3) update [VpnController.state] as new states arrive.
///
/// Calling [VpnController.stop] will:
/// - call [VpnRepository.stop],
/// - cancel any active VPN state subscription,
/// - reset [VpnController.state] to [VpnState.disconnected].
///
/// ## Logs collection
/// Logs are collected by subscribing to [VpnRepository.listenToLogs].
/// The scope stores logs in memory and keeps only the most recent entries
/// (see the internal log limit) to avoid unbounded growth.
///
/// ## Usage
/// Place the scope above any widgets that need VPN state/control:
///
/// ```dart
/// VpnScope(
///   vpnRepository: repository,
///   child: MyApp(),
/// )
/// ```
///
/// Then, inside the subtree:
///
/// ```dart
/// final vpn = VpnScope.vpnControllerOf(context); // subscribes by default
/// final logs = VpnScope.logsControllerOf(context, listen: false); // read only
/// ```
///
/// ## Errors
/// The `*Of` methods throw if called outside of a `VpnScope` subtree. Use the
/// `*MaybeOf` variants if you want a nullable result instead.
/// {@endtemplate}
class VpnScope extends StatefulWidget {
  /// Repository used to start/stop the VPN and to listen for state/log updates.
  final VpnRepository vpnRepository;

  /// Initial state exposed before the repository provides real state updates.
  ///
  /// Defaults to [VpnState.disconnected].
  final VpnState initialState;

  /// Widget subtree that receives access to the scope.
  final Widget child;

  /// {@macro vpn_scope}
  const VpnScope({
    required this.child,
    required this.vpnRepository,
    this.initialState = VpnState.disconnected,
    super.key,
  });

  @override
  State<VpnScope> createState() => _VpnScopeState();

  /// {@template vpn_scope_vpn_controller_maybe_of}
  /// Returns the nearest [VpnController] from the widget tree, or `null`.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.vpn]
  /// and will rebuild when the VPN state changes.
  ///
  /// If [listen] is `false`, the controller is read without establishing an
  /// inherited dependency, so the caller will not rebuild automatically.
  /// {@endtemplate}
  static VpnController? vpnControllerMaybeOf(BuildContext context, {bool listen = true}) =>
      _accessScope(context, listen: listen, aspect: VpnAspect.vpn);

  /// {@template vpn_scope_vpn_controller_of}
  /// Returns the nearest [VpnController] from the widget tree.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.vpn]
  /// and will rebuild when the VPN state changes.
  ///
  /// Throws an [ArgumentError] if called outside of a [VpnScope] subtree.
  /// Use [vpnControllerMaybeOf] when a nullable result is acceptable.
  /// {@endtemplate}
  static VpnController vpnControllerOf(BuildContext context, {bool listen = true}) =>
      _accessScope(context, listen: listen, aspect: VpnAspect.vpn) ?? _notFoundInheritedWidgetOfExactType();

  /// {@template vpn_scope_logs_controller_maybe_of}
  /// Returns the nearest [LogController] from the widget tree, or `null`.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.logs]
  /// and will rebuild when the logs list changes.
  ///
  /// If [listen] is `false`, the controller is read without establishing an
  /// inherited dependency.
  /// {@endtemplate}
  static LogController? logsControllerMaybeOf(BuildContext context, {bool listen = true}) =>
      _accessScope(context, listen: listen, aspect: VpnAspect.logs);

  /// {@template vpn_scope_logs_controller_of}
  /// Returns the nearest [LogController] from the widget tree.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.logs]
  /// and will rebuild when the logs list changes.
  ///
  /// Throws an [ArgumentError] if called outside of a [VpnScope] subtree.
  /// Use [logsControllerMaybeOf] when a nullable result is acceptable.
  /// {@endtemplate}
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
