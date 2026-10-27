import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/data/repository/vpn_repository.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/controller/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/controller/vpn_logs_controller.dart';
import 'package:trusttunnel/feature/vpn/models/log_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_aspect.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration_sources.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_exit_handling_mixin.dart';

/// {@template vpn_scope}
/// Provides access to VPN state, logs, and control operations to a widget subtree.
///
/// `VpnScope` is an app-level scope built on top of [InheritedModel] that exposes
/// two "controllers" to descendants:
/// - a [VpnScopeController] (VPN lifecycle + current [VpnState])
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
/// [VpnController] owns the current VPN state. The scope forwards native updates
/// from [VpnRepository.listenToStates] and exposes state through the controller.
///
/// Calling [VpnScopeController.connectToServer] attempts a connection using saved settings.
/// Calling [VpnScopeController.selectAndConnectToServer] saves selection first.
/// Both operations check cancellation before handing the start to native code.
/// All VPN lifecycle operations, including confirmed exit, use the controller's handlers.
///
/// State observation starts with the scope itself and remains active for the
/// scope's entire lifetime, including when VPN changes are initiated outside
/// the app.
///
/// Calling [VpnScopeController.disconnect] will:
/// - call [VpnRepository.stop] for an active session or a submitted start,
/// - wait for native confirmation before exposing [VpnState.disconnected].
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
  /// Resolves the native window controller for error feedback and app exit.
  /// Invoked only on macOS and Windows.
  final ValueGetter<AppWindowController> appWindowControllerProvider;

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
    required this.appWindowControllerProvider,
    required this.child,
    required this.vpnRepository,
    this.initialState = VpnState.disconnected,
    super.key,
  });

  @override
  State<VpnScope> createState() => _VpnScopeState();

  /// {@template vpn_scope_vpn_controller_maybe_of}
  /// Returns the nearest [VpnScopeController] from the widget tree, or `null`.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.vpn]
  /// and will rebuild when the VPN state changes.
  ///
  /// If [listen] is `false`, the controller is read without establishing an
  /// inherited dependency, so the caller will not rebuild automatically.
  /// {@endtemplate}
  static VpnScopeController? vpnControllerMaybeOf(
    BuildContext context, {
    bool listen = true,
  }) => _accessScope(
    context,
    listen: listen,
    aspect: VpnAspect.vpn,
  )?.controller;

  /// {@template vpn_scope_vpn_controller_of}
  /// Returns the nearest [VpnScopeController] from the widget tree.
  ///
  /// If [listen] is `true` (default), the caller subscribes to [VpnAspect.vpn]
  /// and will rebuild when the VPN state changes.
  ///
  /// Throws an [ArgumentError] if called outside of a [VpnScope] subtree.
  /// Use [vpnControllerMaybeOf] when a nullable result is acceptable.
  /// {@endtemplate}
  static VpnScopeController vpnControllerOf(
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

  /// Errors are reported separately from synchronous VPN control methods.
  static Listenable operationErrorsOf(BuildContext context) =>
      _accessScope(context, listen: false)?.operationErrors ?? _notFoundInheritedWidgetOfExactType();

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

class _VpnScopeState extends State<VpnScope> with VpnScopeExitHandlingMixin<VpnScope> implements VpnScopeController {
  late final VpnController _controller;
  late final VpnLogsController _logsController;

  /// Listens to app lifecycle events (resume and exit requested).
  /// Handles desktop exit requests, including confirmation while VPN is active.
  late final AppLifecycleListener _appLifecycleListener;

  /// Combined notifier for VPN lifecycle changes and collected logs.
  /// The inherited model still filters descendant rebuilds by aspect.
  late final Listenable _vpnChangesListenable;

  /// VPN operation errors originate above the MaterialApp, so the UI listens here
  /// to show feedback for both background updates and failed exit requests.
  final _VpnOperationErrorNotifier _operationErrorNotifier = _VpnOperationErrorNotifier();

  VpnConfigurationSources? _configurationSources;
  StreamSubscription<VpnLog>? _logStreamSub;
  StreamSubscription<VpnState>? _vpnStreamSub;

  @override
  VpnState get state => _controller.state.vpnState;

  @override
  String? get currentlyConnectedServerId => _controller.state.currentlyConnectedServerId;

  @override
  bool get isExitProcessing => _controller.state.isExitProcessing;

  @override
  bool get shouldShowExitDialog => _controller.shouldShowExitDialog;

  @override
  bool get isVpnDisconnectedForExit => _controller.isDisconnectedForExit;

  @override
  AppWindowController? get appWindowController => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.windows => widget.appWindowControllerProvider(),
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _logsController = VpnLogsController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dependencies are app-level scopes with the same lifetime as this scope.
    if (_configurationSources != null) {
      return;
    }

    final servers = ServersScope.controllerOf(context, listen: false);
    final sources = VpnConfigurationSources(
      serversScopeController: servers,
      routingScopeController: RoutingScope.controllerOf(context, listen: false),
      appLoggingScopeController: AppLoggingScope.controllerOf(context, listen: false),
      excludedRoutesScopeController: ExcludedRoutesScope.controllerOf(context, listen: false),
    );

    _configurationSources = sources;
    _controller = VpnController(
      repository: widget.vpnRepository,
      sources: sources,
      saveSelection: servers.selectServer,
      notifyOperationError: _onOperationError,
      onExitStopped: completeVpnExitStop,
      initialState: widget.initialState,
    );
    _vpnChangesListenable = Listenable.merge([_controller, _logsController]);

    // VPN also runs while minimized, when only the tray is visible. Listen to settings directly
    // so synchronization does not depend on Flutter scheduling a frame or rebuilding this scope.
    sources.addListener(_controller.onSourcesChanged);
    _appLifecycleListener = AppLifecycleListener(
      onResume: _controller.onResumed,
      onExitRequested: _onExitRequested,
    );

    _controller.onSourcesChanged();
    unawaited(_listenToVpnStates());
    unawaited(_listenToLogs());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _vpnChangesListenable,
    builder: (_, child) => _InheritedVpnScope(
      controller: this,
      logs: _logsController.logs,
      state: state,
      currentlyConnectedServerId: currentlyConnectedServerId,
      isExitProcessing: isExitProcessing,
      operationErrors: _operationErrorNotifier,
      child: child!,
    ),
    child: widget.child,
  );

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _controller.removeListener(listener);

  @override
  void connectToServer(String serverId, {bool isFromAutomaticLaunch = false}) =>
      _controller.connectToServer(serverId, isFromAutomaticLaunch: isFromAutomaticLaunch);

  @override
  void selectAndConnectToServer(String serverId) => _controller.selectAndConnectToServer(serverId);

  @override
  void disconnect() => _controller.disconnect();

  @override
  void onAppExiting() => _controller.onAppExiting();

  @override
  void cancelVpnExit() => _controller.cancelExit();

  @override
  void requestVpnStopForExit() => _controller.stopForExit();

  /// Reveals the main window and notifies the UI about a VPN operation error.
  @override
  Future<void> notifyVpnOperationError() async {
    if (!mounted) {
      return;
    }

    try {
      await appWindowController?.showMainWindow();
    } catch (error, stackTrace) {
      // Continue notifying the UI even if revealing the window itself fails.
      logger.logError(
        'Unable to show window after VPN operation error',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (mounted) {
      _operationErrorNotifier.notifyListeners();
    }
  }

  void _onOperationError() => unawaited(notifyVpnOperationError());

  Future<void> _listenToVpnStates() async {
    try {
      final stream = await widget.vpnRepository.listenToStates();
      if (!mounted) {
        return;
      }

      _vpnStreamSub = stream.listen(_controller.onNativeStateChanged, onError: _controller.onSourceError);
    } catch (error, stackTrace) {
      _controller.onSourceError(error, stackTrace);
    }
  }

  Future<void> _listenToLogs() async {
    try {
      final stream = await widget.vpnRepository.listenToLogs();
      if (!mounted) {
        return;
      }

      _logStreamSub = stream.listen(_logsController.onLogCollected, onError: _controller.onSourceError);
    } catch (error, stackTrace) {
      _controller.onSourceError(error, stackTrace);
    }
  }

  Future<AppExitResponse> _onExitRequested() => handleAppExitRequested();

  void _onSubscriptionError(Object error, StackTrace stackTrace) => logger.logError(
    'Unable to cancel VPN subscription',
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void dispose() {
    disposeVpnExitHandling();
    _configurationSources?.removeListener(_controller.onSourcesChanged);
    _appLifecycleListener.dispose();

    unawaited(_logStreamSub?.cancel().catchError(_onSubscriptionError));
    unawaited(_vpnStreamSub?.cancel().catchError(_onSubscriptionError));

    _controller.dispose();
    _logsController.dispose();
    _operationErrorNotifier.dispose();
    super.dispose();
  }
}

final class _VpnOperationErrorNotifier extends ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();
}

class _InheritedVpnScope extends InheritedModel<VpnAspect> implements LogController {
  final VpnScopeController controller;

  @override
  final List<VpnLog> logs;

  final VpnState state;
  final String? currentlyConnectedServerId;
  final bool isExitProcessing;
  final Listenable operationErrors;

  const _InheritedVpnScope({
    required this.controller,
    required this.state,
    required this.currentlyConnectedServerId,
    required this.isExitProcessing,
    required this.logs,
    required this.operationErrors,
    required super.child,
  });

  @override
  bool updateShouldNotify(covariant _InheritedVpnScope oldWidget) =>
      _shouldNotifyLogController(oldWidget) || _shouldNotifyVpnController(oldWidget);

  @override
  bool updateShouldNotifyDependent(covariant _InheritedVpnScope oldWidget, Set<VpnAspect> dependencies) {
    final listensToVpn = dependencies.contains(VpnAspect.vpn);
    if (listensToVpn && _shouldNotifyVpnController(oldWidget)) {
      return true;
    }

    final listensToLogs = dependencies.contains(VpnAspect.logs);
    if (listensToLogs && _shouldNotifyLogController(oldWidget)) {
      return true;
    }

    return false;
  }

  bool _shouldNotifyVpnController(_InheritedVpnScope oldWidget) {
    final hasConnectionChanged =
        oldWidget.state != state || oldWidget.currentlyConnectedServerId != currentlyConnectedServerId;

    return hasConnectionChanged || oldWidget.isExitProcessing != isExitProcessing;
  }

  bool _shouldNotifyLogController(_InheritedVpnScope oldWidget) => !listEquals(oldWidget.logs, logs);
}
