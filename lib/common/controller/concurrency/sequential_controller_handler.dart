import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import '../controller/controller.dart';

/// {@template sequential_controller_handler}
/// Mixin that enforces sequential (FIFO) execution of controller handlers.
///
/// All calls to [handle] will be placed into an internal queue and processed
/// one by one in the order they were received.
/// {@endtemplate}
base mixin SequentialControllerHandler on BaseController {
  final _ControllerEventQueue _eventQueue = _ControllerEventQueue();

  /// Indicates whether there are any queued or currently running tasks.
  @override
  @nonVirtual
  bool get isProcessing => _eventQueue.length > 0;

  /// Enqueues an operation and runs it when all previous tasks
  /// have finished.
  @override
  @protected
  @mustCallSuper
  Future<void> handle(
    FutureOr<void> Function() handler, {
    FutureOr<void> Function(Object error, StackTrace stackTrace)? errorHandler,
    FutureOr<void> Function()? completionHandler,
  }) => _eventQueue
      .add<void>(
        () {
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
        },
      )
      .catchError((_, _) => null);
}

/// {@template sequential_controller_handler}
/// Internal FIFO queue responsible for coordinating sequential execution.
/// {@endtemplate}
final class _ControllerEventQueue {
  final DoubleLinkedQueue<_SequentialTask<Object?>> _queue = DoubleLinkedQueue<_SequentialTask<Object?>>();

  bool _isClosed = false;
  Future<void>? _processing;

  /// Number of pending tasks.
  int get length => _queue.length;

  /// Adds a new task to the queue.
  Future<T> add<T>(Future<T> Function() function) {
    final task = _SequentialTask<T>(function);
    _queue.add(task);
    _run();

    return task.future;
  }

  /// Marks the queue as closed.
  ///
  /// All pending tasks complete normally, but new tasks immediately fail.
  Future<void> close() async {
    _isClosed = true;
    await _processing;
  }

  /// Starts processing the queue if not already running.
  void _run() => _processing ??= Future.doWhile(() async {
    final task = _queue.first;
    try {
      if (_isClosed) {
        task.reject(StateError('Controller event queue has been closed.'), StackTrace.current);
      } else {
        await task();
      }
    } on Object catch (error, stackTrace) {
      Future<void>.sync(() => task.reject(error, stackTrace)).ignore();
    }
    _queue.removeFirst();
    final isEmpty = _queue.isEmpty;
    if (isEmpty) _processing = null;

    return !isEmpty;
  });
}

/// {@template sequential_controller_handler}
/// Wrapper around a queued task.
/// {@endtemplate}
class _SequentialTask<T> {
  final Completer<T> _completer;

  final Future<T> Function() _function;

  _SequentialTask(Future<T> Function() function) : _function = function, _completer = Completer<T>();

  Future<T> get future => _completer.future;

  Future<T> call() async {
    final result = await _function();
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }

    return result;
  }

  void reject(Object error, [StackTrace? stackTrace]) {
    if (_completer.isCompleted) return;
    _completer.completeError(error, stackTrace);
  }
}
