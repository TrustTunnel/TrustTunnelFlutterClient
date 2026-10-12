import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/data/repository/vpn_repository.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/models/log_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_aspect.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration_sources.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_exit_handling_mixin.dart';

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
/// - Consumers that subscribe to [VpnAspect.vpn] rebuild when VPN state,
///   connection identity or exit status changes.
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
/// to a state stream produced by [VpnRepository.listenToStates].
///
/// Calling [VpnController.connectToServer] attempts a connection using saved settings.
/// Calling [VpnController.selectAndConnectToServer] saves selection first.
/// Both operations check cancellation before handing the start to native code.
/// All VPN lifecycle operations, including confirmed exit, use the scope's queue.
///
/// State observation starts with the scope itself and remains active for the
/// scope's entire lifetime, including when VPN changes are initiated outside
/// the app.
///
/// Calling [VpnController.disconnect] will:
/// - call [VpnRepository.stop] for an active session or a submitted start,
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
  /// Provided on macOS and Windows to show the window on errors and coordinate app exit.
  /// `null` on other platforms because native window control is not implemented there.
  final AppWindowController? appWindowController;

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
    required this.appWindowController,
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
  static VpnController? vpnControllerMaybeOf(
    BuildContext context, {
    bool listen = true,
  }) => _accessScope(
    context,
    listen: listen,
    aspect: VpnAspect.vpn,
  )?.controller;

  /// {@template vpn_scope_vpn_controller_of}
  /// Returns the nearest [VpnController] from the widget tree.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.vpn]
  /// and will rebuild when the VPN state changes.
  ///
  /// Throws an [ArgumentError] if called outside of a [VpnScope] subtree.
  /// Use [vpnControllerMaybeOf] when a nullable result is acceptable.
  /// {@endtemplate}
  static VpnController vpnControllerOf(
    BuildContext context, {
    bool listen = true,
  }) =>
      _accessScope(
        context,
        listen: listen,
        aspect: VpnAspect.vpn,
      )?.controller ??
      _notFoundInheritedWidgetOfExactType();

  /// {@template vpn_scope_logs_controller_maybe_of}
  /// Returns the nearest [LogController] from the widget tree, or `null`.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.logs]
  /// and will rebuild when the logs list changes.
  ///
  /// If [listen] is `false`, the controller is read without establishing an
  /// inherited dependency.
  /// {@endtemplate}
  static LogController? logsControllerMaybeOf(
    BuildContext context, {
    bool listen = true,
  }) => _accessScope(
    context,
    listen: listen,
    aspect: VpnAspect.logs,
  );

  /// {@template vpn_scope_logs_controller_of}
  /// Returns the nearest [LogController] from the widget tree.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.logs]
  /// and will rebuild when the logs list changes.
  ///
  /// Throws an [ArgumentError] if called outside of a [VpnScope] subtree.
  /// Use [logsControllerMaybeOf] when a nullable result is acceptable.
  /// {@endtemplate}
  static LogController logsControllerOf(
    BuildContext context, {
    bool listen = true,
  }) =>
      _accessScope(
        context,
        listen: listen,
        aspect: VpnAspect.logs,
      ) ??
      _notFoundInheritedWidgetOfExactType();

  static _InheritedVpnScope? _accessScope(
    BuildContext context, {
    bool listen = true,
    VpnAspect? aspect,
  }) => (listen
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

class _VpnScopeState extends State<VpnScope> with VpnScopeExitHandlingMixin<VpnScope> implements VpnController {
  static const _logLimit = 500;

  late final ValueNotifier<VpnState> _stateNotifier;
  late final ValueNotifier<String?> _lastConnectionServerIdNotifier;
  late final ValueNotifier<String?> _currentlyConnectedServerIdNotifier;
  late final ValueNotifier<bool> _isExitProcessingNotifier;
  late final ValueNotifier<List<VpnLog>> _logsNotifier;

  /// Combined notifier for all changes to the VPN state or connection server ID.
  late final Listenable _vpnListenable;

  /// VPN operation errors originate above the [MaterialApp], so the UI listens here
  /// to show feedback for both background updates and failed exit requests.
  late final _OperationErrorNotifier _operationErrorNotifier;

  /// Listens to app lifecycle events (resume and exit requested).
  /// Handles desktop exit requests, including confirmation while VPN is active.
  late final AppLifecycleListener _appLifecycleListener;

  late ServersScopeController _serversScopeController;

  StreamSubscription<VpnLog>? _logStreamSub;
  StreamSubscription<VpnState>? _vpnStreamSub;

  /// Tracks state updates so a delayed request cannot overwrite a newer VPN state.
  int _vpnStateRevision = 0;

  /// Last observed choice request, including choices that did not change persisted selection.
  int _selectionRequestRevision = 0;

  /// It is used to wait for all sources to become ready, since different data sources are asynchronous and not synchronized.
  ///
  /// It may happen that when a connection is established, some data has been loaded while other data has not.
  /// In this case, we need to wait for the data to load completely;
  /// this is why we need this [Completer], as it primarily addresses the issue of the order in which operations are completed,
  /// rather than their absolute duration.
  ///
  /// When all sources are ready, it is not created at all, and the connection proceeds immediately.
  Completer<void>? _sourcesChanged;

  /// The queue is used to manage the order of vpn operations.
  Future<void> _queue = Future<void>.value();

  /// Record that there is already a background synchronization waiting in the queue—there's no need to add another one just yet.
  bool _updateQueued = false;

  /// Shows the user’s most recent intention.
  ///
  /// Example:
  /// 1. The user clicked “Connect to A.” "Tag" #1 was created, and the system began waiting for the settings to load.
  /// 2. The user clicked “Connect to B.” "Tag" #2 was created.
  /// 3. The settings were loaded. Operation A compares its "tag" with the current one, detects a mismatch, and terminates.
  /// 4. Operation B continues the connection.
  ///
  /// Comparing by serverId is not enough. The user may select A twice: the old intent should be canceled, even though the id is the same.
  _VpnRequestIntent? _latestRequestIntent;

  // Because even with the latest native state, we cannot track all the commands in the queue,
  // and managing the state is more complex overall, we need additional flags
  /// The start has been initiated, but its result cannot yet be considered certain based solely on the current state.
  bool _startSubmitted = false;

  /// The stop request has been sent, but the “disconnected” confirmation from the native has not yet been received.
  bool _stopSubmitted = false;

  /// Record that, with an empty list of servers, we have already successfully cleared the VPN configuration.
  ///
  /// It is needed because synchronization is triggered multiple times—when servers, settings, or VPN status change.
  /// This flag helps us avoid multiple unnecessary requests.
  bool _configurationDeleted = false;

  /// Waits for the native vpn disconnection to fully complete.
  Completer<void>? _nativeDisconnectionWaiter;

  VpnConfigurationSources? _configurationSources;
  Server? _configuredServer;
  RoutingProfile? _configuredRoutingProfile;
  List<String>? _configuredExcludedRoutes;
  VpnConfigurationLogLevel? _configuredLogLevel;

  @override
  VpnState get state => _stateNotifier.value;

  @override
  String? get lastConnectionServerId => _lastConnectionServerIdNotifier.value;

  @override
  String? get currentlyConnectedServerId => _currentlyConnectedServerIdNotifier.value;

  @override
  bool get hasPendingStart => _startSubmitted;

  @override
  bool get isExitProcessing => _isExitProcessingNotifier.value;

  @override
  Listenable get operationErrorListenable => _operationErrorNotifier;

  @override
  void initState() {
    super.initState();
    _stateNotifier = ValueNotifier(widget.initialState);
    _lastConnectionServerIdNotifier = ValueNotifier(null);
    _currentlyConnectedServerIdNotifier = ValueNotifier(null);
    _isExitProcessingNotifier = ValueNotifier(false);
    _vpnListenable = Listenable.merge([
      _stateNotifier,
      _lastConnectionServerIdNotifier,
      _currentlyConnectedServerIdNotifier,
      _isExitProcessingNotifier,
    ]);
    _logsNotifier = ValueNotifier(<VpnLog>[]);
    _operationErrorNotifier = _OperationErrorNotifier();
    _appLifecycleListener = AppLifecycleListener(
      onResume: _onAppResumed,
      onExitRequested: _onExitRequested,
    );

    unawaited(_listenToVpnStates());
    unawaited(_listenToLogs());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configurationSources != null) {
      return;
    }

    _serversScopeController = ServersScope.controllerOf(context, listen: false);
    final routingScopeController = RoutingScope.controllerOf(context, listen: false);
    final appLoggingScopeController = AppLoggingScope.controllerOf(context, listen: false);
    final excludedRoutesScopeController = ExcludedRoutesScope.controllerOf(context, listen: false);
    _configurationSources = VpnConfigurationSources(
      serversScopeController: _serversScopeController,
      routingScopeController: routingScopeController,
      appLoggingScopeController: appLoggingScopeController,
      excludedRoutesScopeController: excludedRoutesScopeController,
    );

    _selectionRequestRevision = _serversScopeController.selectionRequestRevision;
    if (_selectionRequestRevision > 0) {
      _latestRequestIntent = _VpnRequestIntent();
    }
    _configurationSources!.addListener(_onSourcesChanged);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(
      [
        _vpnListenable,
        _logsNotifier,
      ],
    ),
    builder: (_, child) => _InheritedVpnScope(
      controller: this,
      logs: _logsNotifier.value,
      state: _stateNotifier.value,
      lastConnectionServerId: lastConnectionServerId,
      currentlyConnectedServerId: currentlyConnectedServerId,
      isExitProcessing: isExitProcessing,
      child: child!,
    ),
    child: widget.child,
  );

  @override
  void addListener(VoidCallback listener) => _vpnListenable.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _vpnListenable.removeListener(listener);

  @override
  Future<void> connectToServer(String serverId, {bool isFromAutomaticLaunch = false}) {
    final isRequestPendingOrActive =
        (_latestRequestIntent != null || state != VpnState.disconnected || hasPendingStart);

    // Automatic launch is accepted only before the first VPN intent.
    if (isExitProcessing || (isFromAutomaticLaunch && isRequestPendingOrActive)) {
      return Future<void>.value();
    }
    final intent = _beginRequest(serverId: serverId);

    return _connectWhenReady(serverId, intent);
  }

  @override
  Future<void> selectAndConnectToServer(String serverId) {
    if (isExitProcessing) {
      return Future<void>.value();
    }

    // Selection notifies synchronously. Capture our intent after that notification,
    // before any await, and retain it throughout saving and connecting.
    final selectionOperation = _serversScopeController.selectServer(serverId);
    final intent = _beginRequest(serverId: serverId);

    return _connectWhenReady(
      serverId,
      intent,
      selectionOperation: selectionOperation,
    );
  }

  @override
  Future<void> disconnect() {
    _beginRequest();

    // An explicit stop must execute before a subsequent connection.
    return _enqueue(_stop);
  }

  @override
  Future<void> synchronizeConfiguration() {
    if (!mounted || _updateQueued || isExitProcessing) {
      return Future<void>.value();
    }
    _updateQueued = true;

    return _enqueue(() async {
      _updateQueued = false;
      await _synchronizeConfiguration();
    });
  }

  @override
  void beginVpnExit() => _beginExit();

  @override
  void cancelVpnExit() => _isExitProcessingNotifier.value = false;

  @override
  Future<void> stopVpnForExit({Duration? timeout}) => _stopAndWaitUntilDisconnected(timeout: timeout);

  @override
  Future<void> notifyVpnOperationError() => _notifyOnOperationError();

  _VpnRequestIntent _beginRequest({String? serverId}) {
    final requestIntent = _VpnRequestIntent(pendingServerId: serverId);
    _latestRequestIntent = requestIntent;
    _wakeWaitingOperation();

    return requestIntent;
  }

  bool _isCurrent(_VpnRequestIntent? requestIntent) =>
      mounted && !isExitProcessing && identical(_latestRequestIntent, requestIntent);

  Future<void> _connectWhenReady(
    String serverId,
    _VpnRequestIntent requestIntent, {
    Future<bool>? selectionOperation,
  }) async {
    try {
      if (selectionOperation != null && !(await selectionOperation)) {
        return;
      }

      // Saving and initial loading do not occupy the VPN queue or delay exit.
      if (!await _waitForDependencies(requestIntent)) {
        return;
      }

      await _enqueue(
        () => _applyConfiguration(
          serverId,
          requestIntent,
          connect: true,
        ),
      );
    } catch (error, stackTrace) {
      await _reportOperationError(error, stackTrace);
    } finally {
      if (identical(_latestRequestIntent, requestIntent)) {
        requestIntent.pendingServerId = null;
      }

      // Changes observed while this intent was pending must still be applied.
      unawaited(synchronizeConfiguration());
    }
  }

  /// The queue remains usable after failure and never repeats a completed command.
  Future<void> _enqueue(Future<void> Function() vpnOperation, {bool reportErrors = true}) {
    final command = _queue.then((_) async {
      if (!mounted) {
        return;
      }

      if (!reportErrors) {
        // Exit owns its feedback and must receive errors to refuse exiting.
        await vpnOperation();

        return;
      }
      try {
        await vpnOperation();
      } catch (error, stackTrace) {
        await _reportOperationError(error, stackTrace);
      }
    });
    _queue = command.catchError((Object error, StackTrace stackTrace) {
      // Errors from exit propagate to its caller without breaking later commands.
      if (reportErrors) {
        try {
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
        } catch (_) {
          // A failing global error handler must not ruin the queue either.
        }
      }
    });

    return reportErrors ? _queue : command;
  }

  Future<void> _reportOperationError(Object error, StackTrace stackTrace) async {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'VPN operations',
      ),
    );

    if (mounted) {
      await _notifyOnOperationError();
    }
  }

  void _wakeWaitingOperation() {
    final waiter = _sourcesChanged;
    _sourcesChanged = null;
    waiter?.complete();
  }

  void _onSourcesChanged() {
    final selectionRequestRevision = _serversScopeController.selectionRequestRevision;
    if (selectionRequestRevision != _selectionRequestRevision) {
      _selectionRequestRevision = selectionRequestRevision;
      _beginRequest();
    }

    final targetId = _latestRequestIntent?.pendingServerId;
    if (targetId != null &&
        !_configurationSources!.serversLoading &&
        _configurationSources!.serversError == null &&
        !_configurationSources!.servers.any((server) => server.id == targetId)) {
      // Deletion invalidates the intent even if that ID later reappears.
      _latestRequestIntent = _VpnRequestIntent();
    }
    _wakeWaitingOperation();
  }

  Future<bool> _waitForDependencies(_VpnRequestIntent? requestIntent) async {
    while (_isCurrent(requestIntent) && _dependenciesLoading) {
      final waiter = _sourcesChanged ??= Completer<void>();
      await waiter.future;
    }

    return _isCurrent(requestIntent) && !_dependenciesFailed;
  }

  ({
    Server server,
    RoutingProfile routingProfile,
    List<String> excludedRoutes,
    VpnConfigurationLogLevel logLevel,
  })?
  _configurationFor(String? serverId) => _configurationSources!.configurationFor(serverId);

  Future<void> _synchronizeConfiguration() async {
    if (isExitProcessing ||
        _dependenciesLoading ||
        _dependenciesFailed ||
        _latestRequestIntent?.pendingServerId != null) {
      return;
    }
    if (_configurationSources!.servers.isEmpty) {
      if (!_configurationDeleted) {
        await _deleteConfiguration();
        _configuredServer = null;
        _configuredRoutingProfile = null;
        _configuredExcludedRoutes = null;
        _configuredLogLevel = null;
        _configurationDeleted = true;
      }

      return;
    }
    _configurationDeleted = false;

    final running = state != VpnState.disconnected || hasPendingStart;
    final connectedId = currentlyConnectedServerId;
    if (running && connectedId == null) {
      // A restored native session cannot be identified by the persisted selection.
      return;
    }
    if (running && !_configurationSources!.servers.any((server) => server.id == connectedId)) {
      await _stop();

      return;
    }

    final targetId = running ? connectedId : (_configurationSources!.selectedServer?.id ?? _configuredServer?.id);
    final configuration = _configurationFor(targetId);
    if (configuration == null) {
      return;
    }
    final changed =
        _configuredServer != configuration.server ||
        _configuredRoutingProfile != configuration.routingProfile ||
        _configuredLogLevel != configuration.logLevel ||
        !listEquals(_configuredExcludedRoutes, configuration.excludedRoutes);
    if (changed) {
      await _applyConfiguration(
        configuration.server.id,
        _latestRequestIntent,
        connect: running,
      );
    }
  }

  Future<void> _applyConfiguration(
    String serverId,
    _VpnRequestIntent? requestIntent, {
    required bool connect,
  }) async {
    if (!await _waitForDependencies(requestIntent) || _configurationFor(serverId) == null) {
      return;
    }

    if (connect) {
      await _stop();
      // Dependencies may change while native stop is in progress.
      if (!await _waitForDependencies(requestIntent)) {
        return;
      }
    }

    final configuration = _configurationFor(serverId);
    if (configuration == null || !_isCurrent(requestIntent)) {
      return;
    }

    final apply = connect ? _start : _updateConfiguration;
    await apply(
      server: configuration.server,
      routingProfile: configuration.routingProfile,
      excludedRoutes: configuration.excludedRoutes,
      logLevel: configuration.logLevel,
    );

    // A submitted native operation finishes even if a newer intention arrived.
    _configuredServer = configuration.server;
    _configuredRoutingProfile = configuration.routingProfile;
    _configuredExcludedRoutes = configuration.excludedRoutes;
    _configuredLogLevel = configuration.logLevel;
    _configurationDeleted = false;
  }

  void _beginExit() {
    _isExitProcessingNotifier.value = true;
    // Cancelling exit on error must not revive an earlier connection intention.
    _beginRequest();
  }

  Future<void> _deleteConfiguration() async {
    await _stop();

    return widget.vpnRepository.deleteConfiguration();
  }

  Future<void> _start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  }) async {
    if (!mounted || isExitProcessing) {
      return;
    }
    // The queued connection has stopped the previous session and checked its request.
    _lastConnectionServerIdNotifier.value = server.id;
    _currentlyConnectedServerIdNotifier.value = server.id;
    _setVpnState(VpnState.connecting, native: false);
    _startSubmitted = true;
    final revisionBeforeStart = _vpnStateRevision;
    final request = Future<void>.sync(
      () => widget.vpnRepository.start(
        server: server,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
        logLevel: logLevel,
      ),
    );
    try {
      await request;
    } catch (_) {
      if (mounted && revisionBeforeStart == _vpnStateRevision) {
        _currentlyConnectedServerIdNotifier.value = null;
        _setVpnState(VpnState.disconnected, native: false);
      }
      // Keep the submitted-start flag: a failing reply can still have reached native code.
      rethrow;
    }
  }

  Future<void> _updateConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  }) => widget.vpnRepository.updateConfiguration(
    server: server,
    routingProfile: routingProfile,
    excludedRoutes: excludedRoutes,
    logLevel: logLevel,
  );

  /// Stops the VPN and immediately changes the state to disconnected.
  Future<void> _stop() async {
    if (!mounted || (_stateNotifier.value == VpnState.disconnected && !_startSubmitted)) {
      return;
    }

    _stopSubmitted = true;
    await widget.vpnRepository.stop();
    if (mounted) {
      _startSubmitted = false;
      _setVpnState(VpnState.disconnected, native: false);
    }
  }

  /// Stops the VPN and waits for the native side to report disconnection.
  Future<void> _stopAndWaitUntilDisconnected({Duration? timeout}) async {
    final disconnectedCompleter = Completer<void>();
    var finished = false;

    Future<void> stopQueuedSession() async {
      if (finished || !mounted) {
        if (!disconnectedCompleter.isCompleted) {
          disconnectedCompleter.complete();
        }

        return;
      }
      if (_stateNotifier.value == VpnState.disconnected && !_startSubmitted && !_stopSubmitted) {
        disconnectedCompleter.complete();

        return;
      }
      _nativeDisconnectionWaiter = disconnectedCompleter;
      // An earlier stop can still be awaiting its native event despite the UI's
      // optimistic disconnected state. Wait for it without sending another stop.
      if (_stateNotifier.value != VpnState.disconnected || _startSubmitted || !_stopSubmitted) {
        _stopSubmitted = true;
        await widget.vpnRepository.stop();
      }
    }

    try {
      Future<void> stopAndWait() async {
        if (finished) {
          return;
        }
        await Future.wait<void>(
          [stopQueuedSession(), disconnectedCompleter.future],
          eagerError: true,
        );
      }

      final stopAndDisconnect = _enqueue(stopAndWait, reportErrors: false);
      if (timeout == null) {
        await stopAndDisconnect;
      } else {
        // One timeout covers the submitted start, stop and native state event.
        await stopAndDisconnect.timeout(timeout);
      }
      _startSubmitted = false;
      if (mounted) {
        _currentlyConnectedServerIdNotifier.value = null;
      }
    } finally {
      // A timed-out exit must not submit a delayed stop after exit was cancelled.
      finished = true;
      if (identical(_nativeDisconnectionWaiter, disconnectedCompleter)) {
        _nativeDisconnectionWaiter = null;
      }
      if (!disconnectedCompleter.isCompleted) {
        disconnectedCompleter.complete();
      }
    }
  }

  void _setVpnState(VpnState state, {bool native = true}) {
    _vpnStateRevision++;
    if (native && state == VpnState.disconnected) {
      // A delayed stop event can precede the new start's first active event.
      if (!_stopSubmitted) {
        _startSubmitted = false;
      }
      _stopSubmitted = false;
      final waiter = _nativeDisconnectionWaiter;
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete();
      }
    }
    if (state != VpnState.disconnected) {
      _startSubmitted = false;
    } else if (!_startSubmitted) {
      _currentlyConnectedServerIdNotifier.value = null;
    }
    _stateNotifier.value = state;
  }

  Future<void> _listenToVpnStates() async {
    final stream = await widget.vpnRepository.listenToStates();
    if (!mounted) {
      return;
    }

    _vpnStreamSub = stream.listen(_setVpnState);
  }

  void _onLogCollected(VpnLog log) {
    final limit = _logLimit;
    var trimmedList = _logsNotifier.value;
    if (_logsNotifier.value.length >= limit) {
      trimmedList = trimmedList.sublist(_logsNotifier.value.length - limit);
    }

    _logsNotifier.value = [...trimmedList, log];
  }

  Future<void> _listenToLogs() async {
    final stream = await widget.vpnRepository.listenToLogs();
    if (!mounted) {
      return;
    }

    _logStreamSub = stream.listen(_onLogCollected);
  }

  Future<void> _refreshState() async {
    final revisionBeforeRequest = _vpnStateRevision;
    final state = await widget.vpnRepository.requestState();
    if (!mounted || revisionBeforeRequest != _vpnStateRevision) {
      return;
    }

    if (state == VpnState.disconnected && _startSubmitted) {
      // The native worker can still be processing the submitted start.
      return;
    }
    _setVpnState(state, native: false);
  }

  void _onAppResumed() => unawaited(_refreshState());

  /// Reveals the main window and notifies the UI about a VPN operation error.
  Future<void> _notifyOnOperationError() async {
    try {
      await widget.appWindowController?.showMainWindow();
    } catch (error, stackTrace) {
      // This is necessary here because we want to continue notifying the UI even if the main window itself closed due to an error
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
    }
    if (mounted) {
      _operationErrorNotifier.notifyListeners();
    }
  }

  Future<AppExitResponse> _onExitRequested() => handleAppExitRequested();

  bool get _dependenciesLoading => _configurationSources!.loading;

  bool get _dependenciesFailed => _configurationSources!.hasErrors;

  @override
  bool get shouldShowExitDialog => _shouldShowExitDialog;

  @override
  bool get isVpnDisconnectedForExit => state == VpnState.disconnected && !_startSubmitted && !_stopSubmitted;

  @override
  AppWindowController? get appWindowController => widget.appWindowController;

  bool get _shouldShowExitDialog =>
      _startSubmitted ||
      switch (_stateNotifier.value) {
        VpnState.connected || VpnState.connecting => true,
        VpnState.disconnected ||
        VpnState.waitingForRecovery ||
        VpnState.recovering ||
        VpnState.waitingForNetwork => false,
      };

  @override
  void dispose() {
    _wakeWaitingOperation();

    _configurationSources?.removeListener(_onSourcesChanged);

    final disconnectionWaiter = _nativeDisconnectionWaiter;
    if (disconnectionWaiter != null && !disconnectionWaiter.isCompleted) {
      disconnectionWaiter.complete();
    }

    _appLifecycleListener.dispose();
    _logStreamSub?.cancel().ignore();
    _vpnStreamSub?.cancel().ignore();
    _stateNotifier.dispose();
    _lastConnectionServerIdNotifier.dispose();
    _currentlyConnectedServerIdNotifier.dispose();
    _isExitProcessingNotifier.dispose();
    _logsNotifier.dispose();
    _operationErrorNotifier.dispose();
    super.dispose();
  }
}

/// Identity marks the current intent; its pending target is cleared after connection work completes.
final class _VpnRequestIntent {
  _VpnRequestIntent({this.pendingServerId});

  String? pendingServerId;
}

final class _OperationErrorNotifier extends ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();
}

class _InheritedVpnScope extends InheritedModel<VpnAspect> implements LogController {
  final VpnController controller;

  @override
  final List<VpnLog> logs;

  final VpnState state;
  final String? lastConnectionServerId;
  final String? currentlyConnectedServerId;
  final bool isExitProcessing;

  const _InheritedVpnScope({
    required this.controller,
    required this.state,
    required this.lastConnectionServerId,
    required this.currentlyConnectedServerId,
    required this.isExitProcessing,
    required this.logs,
    required super.child,
  });

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

  bool _shouldNotifyVpnController(_InheritedVpnScope oldWidget) =>
      oldWidget.state != state ||
      oldWidget.lastConnectionServerId != lastConnectionServerId ||
      oldWidget.currentlyConnectedServerId != currentlyConnectedServerId ||
      oldWidget.isExitProcessing != isExitProcessing;

  bool _shouldNotifyLogController(_InheritedVpnScope oldWidget) => !listEquals(oldWidget.logs, logs);
}
