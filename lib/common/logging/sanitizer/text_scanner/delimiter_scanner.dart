/// Scans for nested collection delimiters while a text value is scanned.
final class DelimiterScanner {
  static const _pairs = {
    '[': ']',
    '{': '}',
    '(': ')',
  };
  static const _standaloneBoundaries = {
    ',',
  };

  static final _openings = _pairs.keys.toSet();
  static final _closings = _pairs.values.toSet();

  /// Map of closing delimiters to opening delimiters.
  /// Example: '}' => '{', ']' => '[', ')' => '('
  static final _openingByClosing = {
    for (final MapEntry(:key, :value) in _pairs.entries) value: key,
  };

  static String closingFor(String char) => _pairs[char]!;

  static bool isOpening(String char) => _openings.contains(char);

  final _openStack = <String>[];

  bool consume(String char) {
    if (isOpening(char)) {
      _openStack.add(char);

      return true;
    }

    final opening = _openingByClosing[char];
    if (opening == null || _openStack.isEmpty || _openStack.last != opening) {
      return false;
    }
    _openStack.removeLast();

    return true;
  }

  bool isValueBoundary(String char) =>
      _openStack.isEmpty && (_standaloneBoundaries.contains(char) || _closings.contains(char));
}
