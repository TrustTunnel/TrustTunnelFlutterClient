import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Internal constants for the INI-like format.
///
/// This is intentionally internal to keep the public surface small.
abstract final class IniConst {
  /// Section header opening bracket: `[` .
  static const sectionOpen = '[';

  /// Section header closing bracket: `]` .
  static const sectionClose = ']';

  /// Comment prefix: `#`.
  static const commentPrefix = '#';

  /// Key/value delimiter: `=`.
  static const equals = '=';

  /// List delimiter: `,`.
  static const comma = ',';

  /// String quote: `"`.
  static const quote = '"';

  /// Multiline string delimiter: `"""`.
  static const multiLine = '"""';

  /// List opening bracket: `[`.
  static const listOpen = '[';

  /// List closing bracket: `]`.
  static const listClose = ']';

  /// IPv6 port divider when a literal is wrapped: `]:`.
  static const ipv6PortDivider = ']:';

  /// IPv4 host/port divider: `:`.
  static const ipv4PortDivider = ':';

  /// Default endpoint port appended when missing.
  static const defaultPort = 443;

  /// Default SOCKS bind address.
  static const defaultSocksAddress = '127.0.0.1:1080';

  /// Default TUN MTU.
  static const defaultTunMtu = 1500;

  /// Default TUN included routes.
  static const defaultTunRoutes = <String>['0.0.0.0/0', '2000::/3'];

  /// Length of the multiline delimiter.
  static const multiLineQuoteLength = 3;
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// An INI-like document with optional sections.
///
/// Use [IniDocument.parse] to parse a text document, and [toString] to serialize.
///
/// Multiline values are supported using triple quotes: `""" ... """`.
@immutable
final class IniDocument {
  /// Creates an empty document.
  IniDocument();

  final LinkedHashMap<String?, IniSection> _sections =
      LinkedHashMap<String?, IniSection>()..[null] = IniSection._(null);

  /// Returns the section map for [name], creating it if missing.
  ///
  /// The top-level section is represented by `null`.
  IniSection section(String? name) => _sections.putIfAbsent(name, () => IniSection._(name));

  @override
  String toString() {
    final StringBuffer out = StringBuffer();
    bool isFirstSection = true;

    for (final MapEntry<String?, IniSection> entry in _sections.entries) {
      final String? sectionName = entry.key;
      final IniSection iniSection = entry.value;

      if (!isFirstSection) out.writeln();
      isFirstSection = false;

      if (sectionName != null) {
        out.writeln('${IniConst.sectionOpen}$sectionName${IniConst.sectionClose}');
      }

      for (final MapEntry<String, IniValue> kv in iniSection.entries) {
        out.writeln('${kv.key} ${IniConst.equals} ${kv.value.encode()}');
      }
    }

    return out.toString();
  }

  /// Parses an INI-like document.
  ///
  /// Supports:
  /// - section headers: `[section]`
  /// - key/value pairs: `key = value`
  /// - multiline values: `""" ... """` (may span multiple lines)
  /// - comments: `# ...`
  static IniDocument parse(String input) {
    final IniDocument document = IniDocument();
    IniSection currentSection = document.section(null);

    final List<String> lines = const LineSplitter().convert(input);

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final String rawLine = lines[lineIndex].trimRight();
      final String line = rawLine.trimLeft();

      if (line.isEmpty || line.startsWith(IniConst.commentPrefix)) continue;

      if (_isSectionHeader(line)) {
        final String sectionName = _parseSectionName(line);
        currentSection = document.section(sectionName.isEmpty ? null : sectionName);
        continue;
      }

      final _KeyValue? kv = _parseKeyValue(line);
      if (kv == null) continue;

      final String key = kv.key;
      final String firstLineValue = kv.value;

      final _MultilineValue? multiline = _readMultiLinedValue(
        lines: lines,
        startLineIndex: lineIndex,
        firstLineValue: firstLineValue,
      );

      if (multiline != null) {
        lineIndex = multiline.lastLineIndex;
        currentSection.setRaw(key, IniValue.parse(multiline.valueToken));
        continue;
      }

      currentSection.setRaw(key, IniValue.parse(firstLineValue));
    }

    return document;
  }

  /// Reads a triple-quoted value token starting at [startLineIndex] if present.
  ///
  /// This searches for the *second* occurrence of the triple-quote delimiter,
  /// starting right after the opening delimiter. This avoids ambiguous
  /// `startsWith/endsWith` logic where start and end markers look identical.
  static _MultilineValue? _readMultiLinedValue({
    required List<String> lines,
    required int startLineIndex,
    required String firstLineValue,
  }) {
    final String trimmed = firstLineValue.trimLeft();
    final bool startsWithMultiLine = trimmed.startsWith(IniConst.multiLine);
    if (!startsWithMultiLine) return null;

    final int openLen = IniConst.multiLineQuoteLength;

    // Closing delimiter on the same line.
    final int closeInFirstLine = firstLineValue.indexOf(IniConst.multiLine, openLen);
    if (closeInFirstLine != -1) {
      final int tokenEnd = closeInFirstLine + openLen;
      final String token = firstLineValue.substring(0, tokenEnd);
      return _MultilineValue(valueToken: token, lastLineIndex: startLineIndex);
    }

    // Multiline token: append lines until we find the closing delimiter.
    final StringBuffer tokenBuffer = StringBuffer(firstLineValue);

    for (int i = startLineIndex + 1; i < lines.length; i++) {
      tokenBuffer.write('\n');
      tokenBuffer.write(lines[i].trimRight());

      final String tokenSoFar = tokenBuffer.toString();
      final int closeIndex = tokenSoFar.indexOf(IniConst.multiLine, openLen);

      if (closeIndex != -1) {
        final int tokenEnd = closeIndex + openLen;
        final String token = tokenSoFar.substring(0, tokenEnd);
        return _MultilineValue(valueToken: token, lastLineIndex: i);
      }
    }

    // Unterminated token: treat as-is.
    return _MultilineValue(valueToken: tokenBuffer.toString(), lastLineIndex: lines.length - 1);
  }

  static bool _isSectionHeader(String line) =>
      line.startsWith(IniConst.sectionOpen) && line.endsWith(IniConst.sectionClose);

  static String _parseSectionName(String line) =>
      line.substring(IniConst.sectionOpen.length, line.length - IniConst.sectionClose.length).trim();

  static _KeyValue? _parseKeyValue(String line) {
    final int equalsIndex = line.indexOf(IniConst.equals);
    if (equalsIndex <= 0) return null;

    final String key = line.substring(0, equalsIndex).trim();
    if (key.isEmpty) return null;

    final String value = line.substring(equalsIndex + IniConst.equals.length).trim();
    return _KeyValue(key: key, value: value);
  }
}

/// A key/value pair parsed from a single line.
@immutable
final class _KeyValue {
  /// Parsed key.
  final String key;

  /// Parsed value token text.
  final String value;

  const _KeyValue({required this.key, required this.value});
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// A section inside an [IniDocument].
///
/// Values are stored as [IniValue] instances.
@immutable
final class IniSection {
  IniSection._(this.name);

  /// Section name, or `null` for top-level.
  final String? name;

  final LinkedHashMap<String, IniValue> _kv = LinkedHashMap<String, IniValue>();

  /// All key/value entries in insertion order.
  Iterable<MapEntry<String, IniValue>> get entries => _kv.entries;

  /// Sets a raw [IniValue].
  void setRaw(String key, IniValue value) => _kv[key] = value;

  /// Reads a raw value.
  IniValue? getRaw(String key) => _kv[key];

  /// Stores a string value.
  void setString(String key, String value) => _kv[key] = IniString(value);

  /// Stores a boolean value.
  void setBool(String key, bool value) => _kv[key] = IniBool(value);

  /// Stores an integer value.
  void setInt(String key, int value) => _kv[key] = IniInt(value);

  /// Stores a list of strings.
  void setStringList(String key, List<String> values) =>
      _kv[key] = IniList(values.map(IniString.new).toList(growable: false));

  /// Stores a PEM value as a multiline string.
  ///
  /// The value is normalized to use `\n` line separators.
  void setMultilinePem(String key, String pem) {
    if (pem.isEmpty) {
      _kv[key] = const IniString('');
      return;
    }
    final String normalized = pem.replaceAll(Platform.lineTerminator, '\n');
    _kv[key] = IniString(normalized);
  }

  /// Reads a string-like representation for [key].
  ///
  /// For non-string values, this returns a stringified form:
  /// - bool/int: `toString()`
  /// - list: items joined by comma
  String? getString(String key) {
    final IniValue? value = _kv[key];
    if (value == null) return null;

    return switch (value) {
      IniString(:final value) => value,
      IniInt(:final value) => value.toString(),
      IniBool(:final value) => value.toString(),
      IniList(:final items) => items.whereType<IniString>().map((e) => e.value).join(IniConst.comma),
    };
  }

  /// Reads a boolean value for [key], if possible.
  bool? getBool(String key) {
    final IniValue? value = _kv[key];
    if (value == null) return null;

    return switch (value) {
      IniBool(:final value) => value,
      IniString(:final value) => value == 'true' ? true : (value == 'false' ? false : null),
      _ => null,
    };
  }

  /// Reads an integer value for [key], if possible.
  int? getInt(String key) {
    final IniValue? value = _kv[key];
    if (value == null) return null;

    return switch (value) {
      IniInt(:final value) => value,
      IniString(:final value) => int.tryParse(value),
      _ => null,
    };
  }

  /// Reads a list of strings for [key], if possible.
  List<String>? getStringList(String key) {
    final IniValue? value = _kv[key];
    if (value == null) return null;

    return switch (value) {
      IniList(:final items) => items
          .map(
            (e) => switch (e) {
              IniString(:final value) => value,
              _ => null,
            },
          )
          .whereType<String>()
          .toList(growable: false),
      _ => null,
    };
  }
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// A value node in an INI document.
///
/// Use [IniValue.parse] to parse a value token.
@immutable
sealed class IniValue {
  /// Creates a value node.
  const IniValue();

  /// Serializes this value node into a backend token.
  String encode();

  /// Parses a single value token into an [IniValue].
  ///
  /// Supported:
  /// - `"""..."""` multiline strings
  /// - `"..."` strings
  /// - `true`/`false` booleans
  /// - integers
  /// - lists: `[...]`
  static IniValue parse(String raw) {
    final String token = raw.trim();

    if (_isMultiLinedString(token)) {
      return IniString(_unquoteMultiLined(token));
    }

    if (_isList(token)) {
      return IniList(_parseList(token));
    }

    if (_isQuotedString(token)) {
      return IniString(_unquote(token));
    }

    if (token == 'true') return const IniBool(true);
    if (token == 'false') return const IniBool(false);

    final int? asInt = int.tryParse(token);
    if (asInt != null) return IniInt(asInt);

    return IniString(token);
  }

  static bool _isMultiLinedString(String token) {
    final bool starts = token.startsWith(IniConst.multiLine);
    final bool ends = token.endsWith(IniConst.multiLine);
    final bool longEnough = token.length >= IniConst.multiLineQuoteLength * 2;
    return starts && ends && longEnough;
  }

  static String _unquoteMultiLined(String token) {
    final int q = IniConst.multiLineQuoteLength;
    return token.substring(q, token.length - q);
  }

  static bool _isQuotedString(String token) {
    final bool starts = token.startsWith(IniConst.quote);
    final bool ends = token.endsWith(IniConst.quote);
    final bool longEnough = token.length >= 2;
    return starts && ends && longEnough;
  }

  static String _unquote(String token) => token.substring(1, token.length - 1);

  static bool _isList(String token) {
    final bool starts = token.startsWith(IniConst.listOpen);
    final bool ends = token.endsWith(IniConst.listClose);
    final bool longEnough = token.length >= 2;
    return starts && ends && longEnough;
  }

  static List<IniValue> _parseList(String token) {
    final String inner = token.substring(1, token.length - 1).trim();
    if (inner.isEmpty) return const <IniValue>[];

    final List<IniValue> values = <IniValue>[];
    final StringBuffer buffer = StringBuffer();

    bool isInQuotes = false;
    bool isInMultiLines = false;

    void flush() {
      final String item = buffer.toString().trim();
      buffer.clear();
      if (item.isEmpty) return;
      values.add(IniValue.parse(item));
    }

    for (int i = 0; i < inner.length; i++) {
      final String ch = inner[i];

      final bool startsTriple = i + 2 < inner.length && inner.substring(i, i + 3) == IniConst.multiLine;
      if (startsTriple) {
        isInMultiLines = !isInMultiLines;
        buffer.write(IniConst.multiLine);
        i += 2;
        continue;
      }

      if (!isInMultiLines && ch == IniConst.quote) {
        isInQuotes = !isInQuotes;
        buffer.write(ch);
        continue;
      }

      if (ch == IniConst.comma && !isInQuotes && !isInMultiLines) {
        flush();
        continue;
      }

      buffer.write(ch);
    }

    flush();
    return values;
  }
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// A string value.
///
/// - Encodes single-line strings as `"..."`.
/// - Encodes multiline strings as `"""..."""`.
@immutable
final class IniString extends IniValue {
  /// String contents (unescaped).
  final String value;

  /// Creates a string node.
  const IniString(this.value);

  @override
  String encode() {
    if (value.isEmpty) return '${IniConst.quote}${IniConst.quote}';
    if (value.contains('\n')) return '${IniConst.multiLine}$value${IniConst.multiLine}';
    return '${IniConst.quote}$value${IniConst.quote}';
  }
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// A boolean value.
@immutable
final class IniBool extends IniValue {
  /// Value.
  final bool value;

  /// Creates a boolean node.
  const IniBool(this.value);

  @override
  String encode() => value.toString();
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// An integer value.
@immutable
final class IniInt extends IniValue {
  /// Value.
  final int value;

  /// Creates an integer node.
  const IniInt(this.value);

  @override
  String encode() => value.toString();
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// A list value.
@immutable
final class IniList extends IniValue {
  /// Values in insertion order.
  final List<IniValue> items;

  /// Creates a list node.
  const IniList(this.items);

  @override
  String encode() => '[${items.map((e) => e.encode()).join(', ')}]';
}

/// A parsed multiline value with its span in the source.
///
/// This is used internally by [IniDocument.parse] to collect a `""" ... """`
/// value that may span multiple lines.
@immutable
final class _MultilineValue {
  /// Complete value token including opening and closing delimiters.
  final String valueToken;

  /// The index of the last line consumed by the token.
  final int lastLineIndex;

  const _MultilineValue({
    required this.valueToken,
    required this.lastLineIndex,
  });
}
