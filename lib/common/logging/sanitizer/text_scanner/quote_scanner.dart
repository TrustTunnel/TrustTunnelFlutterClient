/// Scans for quoted text while a sensitive value is scanned.
final class QuoteScanner {
  static const _quotes = {
    '"',
    '\'',
  };

  String? _quote;
  var _escaped = false;

  bool consume(String char) {
    final quote = _quote;

    if (quote == null) {
      if (!isQuote(char)) {
        return false;
      }
      _quote = char;

      return true;
    }

    if (char == quote && !_escaped) {
      _quote = null;
    }
    _escaped = char == r'\' && !_escaped;
    if (char != r'\') {
      _escaped = false;
    }

    return true;
  }

  static bool isQuote(String char) => _quotes.contains(char);
}
