import 'package:trusttunnel/common/logging/sanitizer/text_scanner/delimiter_scanner.dart';
import 'package:trusttunnel/common/logging/sanitizer/text_scanner/quote_scanner.dart';

/// Finds the end of a sensitive value in free-form text.
final class SensitiveValueScanner {
  final RegExp nextKeyPattern;
  final String text;

  const SensitiveValueScanner(
    this.text, {
    required this.nextKeyPattern,
  });

  int valueEndFrom(int start) {
    if (start >= text.length) {
      return start;
    }

    final char = text[start];
    if (QuoteScanner.isQuote(char)) {
      return _quotedEnd(start, char);
    }

    if (DelimiterScanner.isOpening(char)) {
      return _balancedEnd(start);
    }

    return _plainEnd(start);
  }

  int _balancedEnd(int start) {
    final opening = text[start];
    final closing = DelimiterScanner.closingFor(opening);
    final quotes = QuoteScanner();
    var depth = 0;

    for (var index = start; index < text.length; index++) {
      final char = text[index];
      if (quotes.consume(char)) {
        continue;
      }

      if (char == opening) {
        depth++;
      } else if (char == closing && --depth == 0) {
        return index + 1;
      }
    }

    return text.length;
  }

  int _plainEnd(int start) {
    final quotesScanner = QuoteScanner();
    final delimitersScanner = DelimiterScanner();

    for (var index = start; index < text.length; index++) {
      final char = text[index];
      if (quotesScanner.consume(char)) {
        continue;
      }

      if (delimitersScanner.consume(char)) {
        continue;
      }
      if (delimitersScanner.isValueBoundary(char)) {
        return index;
      }
      if (_isLineBreak(char) && _nextLineStartsNewValue(index)) {
        return index;
      }
    }

    return text.length;
  }

  int _quotedEnd(int start, String quote) {
    var escaped = false;

    for (var index = start + 1; index < text.length; index++) {
      final char = text[index];
      if (char == quote && !escaped) {
        return index + 1;
      }
      escaped = char == r'\' && !escaped;
      if (char != r'\') {
        escaped = false;
      }
    }

    return text.length;
  }

  bool _nextLineStartsNewValue(int index) {
    final nextLine = _skipLineBreak(index);

    return nextLine >= text.length || nextKeyPattern.matchAsPrefix(text, nextLine) != null;
  }

  int _skipLineBreak(int index) {
    var result = index;

    while (result < text.length && _isLineBreakPadding(text[result])) {
      result++;
    }

    return result;
  }

  bool _isLineBreak(String char) => char == '\n' || char == '\r';

  bool _isLineBreakPadding(String char) => _isLineBreak(char) || char == ' ' || char == '\t';
}
