import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/file_download_exception.dart';
import 'package:trusttunnel/common/network/http_transport.dart';
import 'package:trusttunnel/common/network/models/file_download_data.dart';
import 'package:trusttunnel/common/network/models/http_client_configuration.dart';

/// Reuses one HTTP transport and allows one file download in a worker isolate.
/// The application scope owns this client. Cancelling a download leaves it reusable.
final class NetworkClient {
  final HttpClientConfiguration configuration;

  NetworkClient({required this.configuration});

  HttpTransport? _transport;
  _FileDownloadSession? _fileDownloadSession;
  Future<void>? _clientCloseFuture;

  Future<HttpClientResponse> get(Uri uri) {
    _checkOpen();

    return (_transport ??= HttpTransport(configuration)).open(uri);
  }

  /// Requires an exact byte count. The caller owns removal of partial files.
  /// Cancellation waits until the worker closes its file and HTTP transport.
  Stream<int> downloadFile({
    required Uri uri,
    required String destinationPath,
    required int expectedSize,
  }) async* {
    _checkOpen();

    if (_fileDownloadSession != null) {
      throw StateError('A file download is already active');
    }

    if (expectedSize <= 0) {
      throw ArgumentError.value(expectedSize, 'expectedSize', 'Must be positive');
    }

    final _FileDownloadSession session = _FileDownloadSession(
      FileDownloadData(
        configuration: configuration,
        uri: uri,
        destinationPath: destinationPath,
        expectedSize: expectedSize,
      ),
    );
    _fileDownloadSession = session;

    try {
      yield* session.stream;
    } finally {
      _fileDownloadSession = null;
    }
  }

  Future<void> close() {
    final Future<void>? clientCloseFuture = _clientCloseFuture;

    if (clientCloseFuture != null) {
      return clientCloseFuture;
    }

    _transport?.close();

    return _clientCloseFuture = _fileDownloadSession?.cancel() ?? Future<void>.value();
  }

  void _checkOpen() {
    if (_clientCloseFuture != null) {
      throw StateError('Network client is closed');
    }
  }
}

final class _FileDownloadSession {
  final FileDownloadData _downloadData;

  _FileDownloadSession(this._downloadData);

  late final StreamController<int> _progress = StreamController<int>(
    onListen: () {
      _downloadCompletionFuture = _run();
    },
    onCancel: cancel,
  );
  late final Future<AsyncError?> _downloadCompletionFuture;
  bool _cancelled = false;
  int _receivedBytes = 0;
  SendPort? _commands;

  Stream<int> get stream => _progress.stream;

  Future<void> cancel() async {
    if (_progress.isClosed) {
      return;
    }

    if (!_cancelled) {
      _cancelled = true;
      _commands?.send(false);
    }

    final AsyncError? failure = await _downloadCompletionFuture;

    if (failure != null && failure.error is! FileDownloadCancelledException) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
  }

  void _onMessage(Object? message) {
    if (_progress.isClosed) {
      return;
    }

    if (message is SendPort) {
      _commands = message;
      message.send(!_cancelled);
    } else if (message is int && !_cancelled) {
      _receivedBytes = message;
      _progress.add(message);
    }
  }

  Future<AsyncError?> _run() async {
    final ReceivePort messages = ReceivePort()..listen(_onMessage);

    try {
      await compute(
        _FileDownloadWorker.runRequest,
        (download: _downloadData, messages: messages.sendPort),
        debugLabel: 'download-file',
      );

      if (_cancelled) {
        throw const FileDownloadCancelledException();
      }

      // Progress messages and the compute result use different channels.
      if (_receivedBytes != _downloadData.expectedSize) {
        _progress.add(_downloadData.expectedSize);
      }

      return null;
    } catch (error, stackTrace) {
      // Closing the client must also notify a listener that has not cancelled.
      if (_progress.hasListener) {
        _progress.addError(error, stackTrace);
      }

      return AsyncError(error, stackTrace);
    } finally {
      // Closing the port also closes its stream and releases its listener.
      messages.close();
      unawaited(_progress.close());
    }
  }
}

typedef _FileDownloadRequest = ({
  FileDownloadData download,
  SendPort messages,
});

abstract final class _FileDownloadWorker {
  static Future<void> runRequest(_FileDownloadRequest request) async {
    final FileDownloadData download = request.download;
    final ReceivePort commands = ReceivePort();
    final Completer<bool> startPermissionCompleter = Completer<bool>();
    HttpTransport? client;
    bool cancelled = false;

    commands.listen((Object? command) {
      if (command == false) {
        cancelled = true;
        client?.close();
      }

      if (!startPermissionCompleter.isCompleted) {
        startPermissionCompleter.complete(command == true);
      }
    });
    request.messages.send(commands.sendPort);

    try {
      final bool shouldStart = await startPermissionCompleter.future;

      if (!shouldStart) {
        throw const FileDownloadCancelledException();
      }

      final HttpTransport downloadClient = HttpTransport(download.configuration);
      client = downloadClient;
      final HttpClientResponse response = await downloadClient.open(download.uri);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download HTTP ${response.statusCode}', uri: download.uri);
      }

      await _writeDownload(
        response: response,
        request: request,
        isCancelled: () => cancelled,
      );
    } catch (error, stackTrace) {
      // Cancellation can close the client before an automatic redirect opens its request.
      final bool closedClient = error is StateError && error.message == 'Client is closed';
      final bool cancelledTransport =
          cancelled &&
          (error is HttpException || error is SocketException || error is TimeoutException || closedClient);

      if (cancelledTransport) {
        throw const FileDownloadCancelledException();
      }

      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      client?.close();
      commands.close();
    }
  }

  static Future<void> _writeDownload({
    required HttpClientResponse response,
    required _FileDownloadRequest request,
    required bool Function() isCancelled,
  }) async {
    final FileDownloadData download = request.download;
    final RandomAccessFile writer = await File(download.destinationPath).open(mode: FileMode.write);
    AsyncError? failure;

    try {
      int receivedBytes = 0;
      int reportedPercentage = -1;

      await for (final List<int> chunk in response.timeout(download.configuration.timeout)) {
        if (isCancelled()) {
          throw const FileDownloadCancelledException();
        }

        receivedBytes += chunk.length;

        if (receivedBytes > download.expectedSize) {
          throw const FileDownloadSizeException();
        }

        await writer.writeFrom(chunk);
        final int percentage = (receivedBytes * 100 ~/ download.expectedSize).clamp(0, 100);

        if (percentage != reportedPercentage) {
          reportedPercentage = percentage;
          request.messages.send(receivedBytes);
        }
      }

      await writer.flush();

      if (isCancelled()) {
        throw const FileDownloadCancelledException();
      }

      if (receivedBytes != download.expectedSize) {
        throw const FileDownloadSizeException();
      }
    } catch (error, stackTrace) {
      failure = AsyncError(error, stackTrace);
      rethrow;
    } finally {
      try {
        await writer.close();
      } catch (error, stackTrace) {
        final Object reportedError = failure == null
            ? error
            : FileDownloadCleanupException(cause: failure.error, cleanupError: error);
        Error.throwWithStackTrace(reportedError, failure?.stackTrace ?? stackTrace);
      }
    }
  }
}
