import 'dart:convert';


import 'package:vpn_plugin/models/logs/log_level.dart';
import 'package:vpn_plugin/models/logs/log_record.dart';

class LogDecoder extends Converter<List<int>, LogRecord> {
  static const int _recordSeparator = 0x1E;
  static const int _space = 0x20;

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

  static const stringSplitter = _StringSplitter();

  @override
  LogRecord convert(List<int> input) => _parse(input);

  @override
  Sink<List<int>> startChunkedConversion(Sink<LogRecord> sink) => _LogDecoderSink(sink);

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

  static LogLevel _parseLevel(String s) {
    switch (s.toLowerCase()) {
      case '[debug]':
        return LogLevel.debug;
      case '[info]':
        return LogLevel.info;
      case '[error]':
        return LogLevel.error;
      case '[warn]':
        return LogLevel.warn;
      default:
        throw FormatException('Unknown log level: $s');
    }
  }
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
