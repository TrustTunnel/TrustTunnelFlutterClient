import 'dart:async';

/// Reads a stream sequentially and permits cancellation while waiting for data.
/// Cancellation and reading both wait for the source to release its resources.
final class CancellableStreamReader<T> {
  final StreamIterator<T> _iterator;

  CancellableStreamReader(Stream<T> source) : _iterator = StreamIterator<T>(source);

  Future<void>? _streamCancellationFuture;

  Stream<T> get stream async* {
    try {
      while (await _iterator.moveNext()) {
        yield _iterator.current;
      }
    } finally {
      await cancel();
    }
  }

  Future<void> cancel() => _streamCancellationFuture ??= _iterator.cancel();
}
