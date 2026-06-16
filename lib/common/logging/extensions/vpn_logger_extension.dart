import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:trusttunnel/common/logging/app_logger.dart';

typedef LogPayloadBuilder = Object? Function();

class VpnLoggerExtension extends LoggerExtension<VpnLoggerExtension> {
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

    logInfo('VPN command $name started', additionalTags: tags);

    _logDetailedPayload(
      'VPN command $name payload',
      payloadBuilder,
      tags,
    );

    try {
      final result = await command();
      logInfo('VPN command $name completed', additionalTags: tags);

      return result;
    } on Object catch (error, stackTrace) {
      logError(
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
        logInfo(
          'Tunnel state changed: ${(logger as AppLogger).sanitizer.sanitize<Object>(state)}',
          additionalTags: const ['vpn', 'state'],
        );
        sink.add(state);
      },
      handleError: (error, stackTrace, sink) {
        logError(
          'VPN state stream failed',
          error: error,
          stackTrace: stackTrace,
          additionalTags: const ['vpn', 'state'],
        );
        sink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        logDebug(
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
        logError(
          'VPN query log stream failed',
          error: error,
          stackTrace: stackTrace,
          additionalTags: const ['vpn', 'query_log'],
        );
        sink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        logDebug(
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
    logDebug(
      '$message: ${(logger as AppLogger).sanitizer.sanitize<Object>(payloadBuilder?.call())}',
      additionalTags: tags,
    );
  }
}
