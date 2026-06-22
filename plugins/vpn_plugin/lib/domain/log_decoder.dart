import 'dart:convert';

import 'package:vpn_plugin/models/logs/log_level.dart';
import 'package:vpn_plugin/models/logs/log_record.dart';

/// {@template log_decoder}
/// Converts raw VPN plugin log bytes into [LogRecord] instances.
///
/// The VPN plugin outputs binary log data with records separated by
/// the `0x1E` (Record Separator) byte. Each record consists of a
/// timestamp, a bracketed level string (e.g. `[info]`), and a message.
///
/// ## Line format
///
/// ```text
/// 2025-01-01T12:00:00.000 [info] VPN connection established
/// ```
///
/// ## Usage
///
/// ```dart
/// final decoder = LogDecoder();
/// final record = decoder.convert(rawBytes);
/// ```
/// {@endtemplate}
class LogDecoder extends Converter<List<int>, LogRecord> {
  /// The byte value used as a record separator (`0x1E`).
  static const int _recordSeparator = 0x1E;

  /// The byte value for a space character (`0x20`).
  static const int _space = 0x20;

  /// {@template log_decoder_parse_line}
  /// Parses a single log line string into a [LogRecord].
  ///
  /// The [line] is expected to have at least three space-separated
  /// tokens: a timestamp, a bracketed level, and a message.
  ///
  /// ### Throws:
  /// - [FormatException]: If the line contains fewer than three tokens.
  /// {@endtemplate}
  static LogRecord parseLine(String line) {
    final parts = line.split(' ');
    if (parts.length < 3) {
      throw FormatException('Invalid log entry: $line');
    }
    return LogRecord(
      dateTime: DateTime.parse(parts[0]),
      level: _parseLevel(parts[1]),
      message: parts.sublist(2).join(' '),
    );
  }

  /// {@template log_decoder_string_splitter}
  /// A pre-constructed [_StringSplitter] for splitting byte streams
  /// on the `0x1E` record separator.
  /// {@endtemplate}
  static const stringSplitter = _StringSplitter();

  @override
  LogRecord convert(List<int> input) => _parse(input);

  @override
  Sink<List<int>> startChunkedConversion(Sink<LogRecord> sink) => _LogDecoderSink(sink);

  /// Parses raw bytes into a [LogRecord].
  ///
  /// Reads the timestamp up to the first space, the bracketed level
  /// up to the second space, and treats the remainder as the message.
  static LogRecord _parse(List<int> bytes) {
    final len = bytes.length;

    var pos = 0;
    while (pos < len && bytes[pos] != _space) {
      pos++;
    }
    final timestamp = DateTime.parse(utf8.decode(bytes.sublist(0, pos)));
    pos++;

    final levelStart = pos;
    while (pos < len && bytes[pos] != _space) {
      pos++;
    }
    final level = _parseLevel(utf8.decode(bytes.sublist(levelStart, pos)));
    pos++;

    final message = utf8.decode(bytes.sublist(pos));

    return LogRecord(dateTime: timestamp, level: level, message: message);
  }

  /// Delegates level parsing to [LogLevel.fromString].
  ///
  /// See [LogLevel.fromString] for details on supported level strings
  /// and fallback behaviour.
  static LogLevel _parseLevel(String s) => LogLevel.fromString(s);
}

class _StringSplitter extends Converter<List<int>, String> {
  static const int _sep = 0x1E;

  const _StringSplitter();

  @override
  String convert(List<int> input) => throw UnimplementedError('use chunked');

  @override
  Sink<List<int>> startChunkedConversion(Sink<String> sink) => _StringSplitterSink(sink);
}

class _StringSplitterSink implements Sink<List<int>> {
  final Sink<String> _out;
  final _buf = <int>[];

  _StringSplitterSink(this._out);

  @override
  void add(List<int> chunk) {
    for (final b in chunk) {
      if (b == _StringSplitter._sep) {
        if (_buf.isNotEmpty) {
          _out.add(utf8.decode(_buf));
          _buf.clear();
        }
      } else {
        _buf.add(b);
      }
    }
  }

  @override
  void close() {
    if (_buf.isNotEmpty) _out.add(utf8.decode(_buf));
    _out.close();
  }
}

class _LogDecoderSink implements Sink<List<int>> {
  final Sink<LogRecord> _out;
  final _buf = <int>[];

  _LogDecoderSink(this._out);

  @override
  void add(List<int> chunk) {
    for (final b in chunk) {
      if (b == LogDecoder._recordSeparator) {
        if (_buf.isNotEmpty) {
          _out.add(LogDecoder._parse(_buf));
          _buf.clear();
        }
      } else {
        _buf.add(b);
      }
    }
  }

  @override
  void close() {
    if (_buf.isNotEmpty) _out.add(LogDecoder._parse(_buf));
    _out.close();
  }
}
