import 'dart:developer';

import 'package:adguard_logger/adguard_logger.dart';

/// A console log appender that works around a Dart VM log-ordering issue
/// by normalising message lengths and forwarding full diagnostic metadata.
///
/// ## The problem
///
/// The Dart VM's [log] function processes messages of different lengths
/// through **different internal code paths** (short messages take the fast
/// path, longer ones may be queued or split).  When the two paths are
/// exercised in rapid succession — as happens during app initialisation —
/// the messages can reach the console out of chronological order.
class CustomConsoleAppender extends ConsoleLogAppender {
  /// Minimum total length every log line is padded to.
  ///
  /// The Dart VM's [log] function uses different internal code paths for
  /// messages shorter vs. longer than this threshold.  When the two paths
  /// are mixed during rapid-fire logging, chronological order can break.
  /// Padding every line to at least this length forces all messages onto
  /// the same path, guaranteeing insertion order in the console.
  ///
  /// As a side-effect this also makes the message portion of every line
  /// start at a fixed column, improving readability.
  static const int _minLogLength = 129;

  @override
  void handle(LogRecord record) {
    final formattedString = formatter.format(record);
    log(
      formattedString.padRight(
        (_minLogLength - formattedString.length).clamp(
          0,
          _minLogLength,
        ),
      ),
      name: 'TrustTunnel Log',
      level: record.level.severity,
      error: record.error,
      stackTrace: record.stackTrace,
      time: record.timeLog.dateTime,
    );
  }
}
