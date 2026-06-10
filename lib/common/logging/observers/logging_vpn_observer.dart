import 'dart:async';

import 'package:trusttunnel/common/logging/app_logger.dart';

typedef LogPayloadBuilder = Object? Function();

final class LoggingVpnObserver {
  final AppLogger _logger;

  LoggingVpnObserver({
    required AppLogger logger,
  }) : _logger = logger;

  Future<void> runCommand(
    String name,
    Future<void> Function() command, {
    LogPayloadBuilder? payloadBuilder,
  }) => runCommandWithResult<void>(
    name,
    command,
    payloadBuilder: payloadBuilder,
  );

  Future<T> runCommandWithResult<T>(
    String name,
    Future<T> Function() command, {
    LogPayloadBuilder? payloadBuilder,
  }) async {
    final tags = ['vpn', name];
    _logger.logInfo('VPN command $name started', additionalTags: tags);
    _logDetailedPayload(
      'VPN command $name payload',
      payloadBuilder,
      tags,
    );

    try {
      final result = await command();
      _logger.logInfo('VPN command $name completed', additionalTags: tags);

      return result;
    } on Object catch (error, stackTrace) {
      _logger.logError(
        'VPN command $name failed',
        error: error,
        stackTrace: stackTrace,
        additionalTags: tags,
      );

      rethrow;
    }
  }

  Stream<T> observeStateStream<T>(Stream<T> stream) => stream.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleData: (state, sink) {
        _logger.logInfo(
          'Tunnel state changed: ${_logger.sanitizePayload(state)}',
          additionalTags: const ['vpn', 'state'],
        );
        sink.add(state);
      },
      handleError: (error, stackTrace, sink) {
        _logger.logError(
          'VPN state stream failed',
          error: error,
          stackTrace: stackTrace,
          additionalTags: const ['vpn', 'state'],
        );
        sink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        _logger.logDebug(
          'VPN state stream completed',
          additionalTags: const ['vpn', 'state'],
        );
        sink.close();
      },
    ),
  );

  Stream<T> observeQueryLogStream<T>(Stream<T> stream) => stream.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleData: (entry, sink) {
        _logDetailedPayload(
          'VPN query log entry',
          () => {'queryLog': entry},
          const ['vpn', 'query_log'],
        );
        sink.add(entry);
      },
      handleError: (error, stackTrace, sink) {
        _logger.logError(
          'VPN query log stream failed',
          error: error,
          stackTrace: stackTrace,
          additionalTags: const ['vpn', 'query_log'],
        );
        sink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        _logger.logDebug(
          'VPN query log stream completed',
          additionalTags: const ['vpn', 'query_log'],
        );
        sink.close();
      },
    ),
  );

  void _logDetailedPayload(
    String message,
    LogPayloadBuilder? payloadBuilder,
    List<String> tags,
  ) {
    if (!_logger.isDebugLoggingEnabled || payloadBuilder == null) {
      return;
    }

    _logger.logDebug(
      '$message: ${_logger.sanitizePayload(payloadBuilder())}',
      additionalTags: tags,
    );
  }
}
