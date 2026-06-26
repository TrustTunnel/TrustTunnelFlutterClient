import 'dart:async';

import 'package:meta/meta.dart';

import '../controller/state_controller.dart';

/// {@template restartable_controller_handler}
/// Mixin that provides restartable concurrency semantics for a state controller.
///
/// Each new [handle] invocation logically cancels all previously started
/// handlers. Older handlers are still physically running but their state
/// updates and callbacks are ignored.
/// {@endtemplate}
base mixin RestartableControllerHandler<S extends Object> on BaseStateController<S> {
  /// Zone key used to propagate the handler generation id.
  static final Object _zoneGenerationKey = Object();

  int _currentGeneration = 0;

  bool _isProcessing = false;

  @override
  @nonVirtual
  bool get isProcessing => _isProcessing;

  /// Handles a given operation with restartable semantics.
  ///
  /// Every new [handler] call invalidates all previously started handlers.
  /// Only the most recent handler is considered active and can:
  /// - call [errorHandler]
  /// - call [completionHandler]
  /// - update the state via [emit]
  @override
  @protected
  @mustCallSuper
  Future<void> handle(
    FutureOr<void> Function() handler, {
    FutureOr<void> Function(Object error, StackTrace stackTrace)? errorHandler,
    FutureOr<void> Function()? completionHandler,
  }) {
    if (isDisposed) return Future<void>.value();
    _isProcessing = true;
    final completer = Completer<void>();
    final int generation = ++_currentGeneration;

    Future<void> onError(Object error, StackTrace stackTrace) async {
      if (isDisposed || generation != _currentGeneration) return;
      try {
        super.onError(error, stackTrace);
        await errorHandler?.call(error, stackTrace);
      } on Object catch (e, st) {
        super.onError(e, st);
      }
    }

    Future<void> onComplete() async {
      if (!isDisposed && generation == _currentGeneration) {
        try {
          await completionHandler?.call();
        } on Object catch (error, stackTrace) {
          super.onError(error, stackTrace);
        }
      }

      // Only the latest handler is allowed to turn off the processing flag.
      if (generation == _currentGeneration) {
        _isProcessing = false;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    runZonedGuarded<void>(
      () async {
        try {
          if (isDisposed) return;
          await handler();
        } on Object catch (error, stackTrace) {
          await onError(error, stackTrace);
        } finally {
          await onComplete();
        }
      },
      super.onError,
      zoneValues: <Object?, Object?>{
        _zoneGenerationKey: generation,
      },
    );

    return completer.future;
  }

  /// Overrides [emit] to ignore state updates coming from obsolete handlers.
  ///
  /// If [emit] is called outside of [handle], the state is always updated.
  @override
  @protected
  @mustCallSuper
  void setState(S newState) {
    final handlerGeneration = Zone.current[_zoneGenerationKey] as int?;
    if (handlerGeneration != null && handlerGeneration != _currentGeneration) return;

    super.setState(newState);
  }
}
