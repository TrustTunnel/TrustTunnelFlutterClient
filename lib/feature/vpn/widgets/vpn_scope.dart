import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/data/repository/vpn_repository.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/app/controller/windows_app_window_controller.dart';
import 'package:trusttunnel/feature/tray_menu/platform/macos/macos_exit_dialog.dart';
import 'package:trusttunnel/feature/tray_menu/platform/windows/windows_exit_dialog.dart';
import 'package:trusttunnel/feature/vpn/models/log_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_aspect.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';

/// {@template vpn_scope_on_start_callback}
/// Signature of the "start VPN" operation used by [VpnScope].
///
/// The callback starts a VPN session for the given [server] and [routingProfile]
/// and applies [excludedRoutes] (typically CIDR ranges) and [logLevel] as part of the configuration.
///
/// The concrete behavior depends on the platform/backend implementation behind
/// the repository, but the callback is expected to complete only after the
/// start request has been handed off to the backend (not necessarily after a
/// successful connection).
/// {@endtemplate}
typedef UpdateVpnCallback =
    Future<void> Function({
      required Server server,
      required RoutingProfile routingProfile,
      required List<String> excludedRoutes,
      required VpnConfigurationLogLevel logLevel,
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
/// to a state stream produced by [VpnRepository.listenToStates].
///
/// Calling [VpnController.start] will:
/// 1) stop any existing session (by calling [VpnController.stop]),
/// 2) start a new VPN session.
///
/// State observation starts with the scope itself and remains active for the
/// scope's entire lifetime, including when VPN changes are initiated outside
/// the app.
///
/// Calling [VpnController.stop] will:
/// - call [VpnRepository.stop] when the VPN is not already disconnected,
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

class _VpnScopeState extends State<VpnScope> implements VpnController {
  static const _logLimit = 500;

  /// On Windows, `stop()` only queues service work, so `disconnected` may never arrive if it fails.
  /// Limit the wait to avoid leaving the app exit request pending forever.
  static const _windowsDisconnectOnExitTimeout = Duration(seconds: 5);

  late final ValueNotifier<VpnState> _stateNotifier;
  late final ValueNotifier<List<VpnLog>> _logsNotifier;

  /// VPN operation errors originate above the [MaterialApp], so the UI listens here
  /// to show feedback for both background updates and failed exit requests.
  late final _OperationErrorNotifier _operationErrorNotifier;

  /// Listens to app lifecycle events (resume and exit requested).
  /// Handles desktop exit requests, including confirmation while VPN is active.
  late final AppLifecycleListener _appLifecycleListener;

  StreamSubscription<VpnLog>? _logStreamSub;
  StreamSubscription<VpnState>? _vpnStreamSub;

  /// The pending exit request for Windows (the same reason as with the timeout)
  Future<AppExitResponse>? _windowsExitRequest;

  // Tracks state updates so a delayed request cannot overwrite a newer VPN state.
  int _vpnStateRevision = 0;

  @override
  VpnState get state => _stateNotifier.value;

  @override
  Listenable get operationErrorListenable => _operationErrorNotifier;

  @override
  void initState() {
    super.initState();
    _stateNotifier = ValueNotifier(widget.initialState);
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(
      [
        _stateNotifier,
        _logsNotifier,
      ],
    ),
    builder: (_, child) => _InheritedVpnScope(
      controller: this,
      logs: _logsNotifier.value,
      state: _stateNotifier.value,
      child: child!,
    ),
    child: widget.child,
  );

  @override
  void addListener(VoidCallback listener) => _stateNotifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _stateNotifier.removeListener(listener);

  @override
  Future<void> start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  }) => _start(
    server: server,
    routingProfile: routingProfile,
    excludedRoutes: excludedRoutes,
    logLevel: logLevel,
  );

  @override
  Future<void> updateConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  }) => _updateConfiguration(
    server: server,
    routingProfile: routingProfile,
    excludedRoutes: excludedRoutes,
    logLevel: logLevel,
  );

  @override
  Future<void> deleteConfiguration() => _deleteConfiguration();

  @override
  Future<void> stop() => _stop();

  @override
  Future<void> notifyOnOperationError() => _notifyOnOperationError();

  bool get _shouldShowExitDialog => switch (_stateNotifier.value) {
    VpnState.connected || VpnState.connecting => true,
    VpnState.disconnected || VpnState.waitingForRecovery || VpnState.recovering || VpnState.waitingForNetwork => false,
  };

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
    await _stop();

    await widget.vpnRepository.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
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
    if (_stateNotifier.value == VpnState.disconnected) {
      return;
    }

    await widget.vpnRepository.stop();
    _setVpnState(VpnState.disconnected);
  }

  /// Stops the VPN and waits for the native side to report disconnection.
  Future<void> _stopAndWaitUntilDisconnected({Duration? timeout}) async {
    if (_stateNotifier.value == VpnState.disconnected) {
      return;
    }

    final disconnectedCompleter = Completer<void>();
    void disconnectedStateListener() {
      if (_stateNotifier.value == VpnState.disconnected && !disconnectedCompleter.isCompleted) {
        disconnectedCompleter.complete();
      }
    }

    _stateNotifier.addListener(disconnectedStateListener);
    try {
      // Future.wait combines stop() and the disconnected event; one timeout covers both.
      final stopAndDisconnect = Future.wait<void>(
        [widget.vpnRepository.stop(), disconnectedCompleter.future],
        eagerError: true,
      );

      if (timeout == null) {
        await stopAndDisconnect;
      } else {
        await stopAndDisconnect.timeout(timeout);
      }
    } finally {
      _stateNotifier.removeListener(disconnectedStateListener);
      if (!disconnectedCompleter.isCompleted) {
        disconnectedCompleter.complete();
      }
    }
  }

  void _setVpnState(VpnState state) {
    _vpnStateRevision++;
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

    _setVpnState(state);
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

  /// Handles the app exit requested event.
  ///
  /// This type of error handling is necessary here because if the `onExitRequested` handler throws an exception,
  /// Flutter will log it but will not count it as a refusal to exit.
  /// If no one explicitly returns `cancel`, the result will be an exit.
  Future<AppExitResponse> _onExitRequested() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final pendingExitRequest = _windowsExitRequest;
      if (pendingExitRequest != null) {
        return pendingExitRequest;
      }

      try {
        final exitRequest = _handleWindowsExitRequested().catchError((
          Object error,
          StackTrace stackTrace,
        ) async {
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
          await _notifyOnOperationError();

          return AppExitResponse.cancel;
        });
        _windowsExitRequest = exitRequest;

        return await exitRequest;
      } finally {
        _windowsExitRequest = null;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        return await _handleMacosExitRequested();
      } catch (error, stackTrace) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
        await _notifyOnOperationError();

        return AppExitResponse.cancel;
      }
    }

    return AppExitResponse.exit;
  }

  Future<AppExitResponse> _handleMacosExitRequested() async {
    final appWindowController = widget.appWindowController;
    if (appWindowController == null) {
      throw StateError('AppWindowController must be provided on macOS');
    }

    if (_shouldShowExitDialog) {
      final localization = Localization.ln;
      final result =
          await MacosExitDialog.show(
            title: localization.exitDialogTitle,
            message: localization.exitDialogDescription,
            quitButtonText: localization.quit,
            dontQuitButtonText: localization.dontQuit,
          ).onError((_, _) async {
            // Here, we ignore the error and the stack trace, since these are native dialogs,
            // and we don't need to know the full stack trace anyway, as the relevant section will be visible
            // (showing that the error occurred in them).
            await _notifyOnOperationError();

            return MacosExitDialogResult.cancel;
          });
      if (!mounted || result != MacosExitDialogResult.quit) {
        return AppExitResponse.cancel;
      }
    }

    await _stopAndWaitUntilDisconnected();
    await appWindowController.setPreventClose(false);

    return AppExitResponse.exit;
  }

  Future<AppExitResponse> _handleWindowsExitRequested() async {
    if (_shouldShowExitDialog) {
      if (!mounted) {
        return AppExitResponse.cancel;
      }
      final localization = Localization.ln;
      WindowsExitDialogResult result;

      result =
          await WindowsExitDialog.show(
            title: localization.exitDialogTitle,
            message: localization.exitDialogDescription,
            quitButtonText: localization.quit,
            dontQuitButtonText: localization.dontQuit,
          ).onError((_, _) async {
            // Here, we ignore the error and the stack trace, since these are native dialogs,
            // and we don't need to know the full stack trace anyway, as the relevant section will be visible
            // (showing that the error occurred in them).
            await _notifyOnOperationError();

            return WindowsExitDialogResult.cancel;
          });

      if (!mounted || result != WindowsExitDialogResult.quit) {
        return AppExitResponse.cancel;
      }
    }
    if (!mounted) {
      return AppExitResponse.cancel;
    }

    final disconnected = await _stopWindowsVpnWithWaitForDisconnection();
    if (disconnected || (mounted && _stateNotifier.value == VpnState.disconnected)) {
      final window = widget.appWindowController;
      if (window is WindowsAppWindowController) {
        await window.prepareToExit();
      }

      return AppExitResponse.exit;
    }

    await _notifyOnOperationError();

    return AppExitResponse.cancel;
  }

  Future<bool> _stopWindowsVpnWithWaitForDisconnection() =>
      _stopAndWaitUntilDisconnected(timeout: _windowsDisconnectOnExitTimeout).then(
        (_) => true,
        onError: (_) => false,
      );

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    _logStreamSub?.cancel().ignore();
    _vpnStreamSub?.cancel().ignore();
    _stateNotifier.dispose();
    _logsNotifier.dispose();
    _operationErrorNotifier.dispose();
    super.dispose();
  }
}

class _OperationErrorNotifier extends ChangeNotifier {
  @override
  void notifyListeners() => super.notifyListeners();
}

class _InheritedVpnScope extends InheritedModel<VpnAspect> implements LogController {
  final VpnController controller;

  @override
  final List<VpnLog> logs;

  final VpnState state;

  const _InheritedVpnScope({
    required this.controller,
    required this.state,
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

  bool _shouldNotifyVpnController(_InheritedVpnScope oldWidget) => oldWidget.state != state;

  bool _shouldNotifyLogController(_InheritedVpnScope oldWidget) => !listEquals(oldWidget.logs, logs);
}
