import 'dart:async';

import 'package:meta/meta.dart';

import '../controller/controller.dart';

/// {@template droppable_controller_handler}
/// Mixin that implements droppable concurrency semantics for a controller.
///
/// Incoming handler calls are ignored while another operation is still running.
/// Only one handler is executed at a time; any additional requests are dropped.
/// {@endtemplate}
base mixin DroppableControllerHandler on BaseController {
  /// Indicates whether there are any queued or currently running tasks.
  @override
  @nonVirtual
  bool get isProcessing => _isProcessing;
  bool _isProcessing = false;

  /// Executes a handler only if the controller is not already processing
  /// another operation. If a handler is already running, the call is ignored.
  @override
  @protected
  @mustCallSuper
  Future<void> handle(
    FutureOr<void> Function() handler, {
    FutureOr<void> Function(Object error, StackTrace stackTrace)? errorHandler,
    FutureOr<void> Function()? completionHandler,
  }) {
    if (isDisposed || isProcessing) return Future<void>.value();
    _isProcessing = true;
    final completer = Completer<void>();

    Future<void> onError(Object e, StackTrace st) async {
      if (isDisposed) return;
      try {
        super.onError(e, st);
        await errorHandler?.call(e, st);
      } on Object catch (error, stackTrace) {
        super.onError(error, stackTrace);
      }
    }

    Future<void> onComplete() async {
      if (!isDisposed) {
        try {
          await completionHandler?.call();
        } on Object catch (error, stackTrace) {
          super.onError(error, stackTrace);
        }
      }

      if (!completer.isCompleted) {
        _isProcessing = false;
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
    );

    return completer.future;
  }
}
