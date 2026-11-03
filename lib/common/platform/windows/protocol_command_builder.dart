/// Builds the command line stored in a Windows URL protocol registration.
final class ProtocolCommandBuilder {
  /// The placeholder Windows replaces with the invoked URL.
  static const String _urlPlaceholder = '%1';

  /// Matches backslash runs that precede a quote or end the argument.
  static final RegExp _backslashesBeforeQuoteOrEnd = RegExp(r'\\+(?="|$)');

  /// Creates a command line builder.
  const ProtocolCommandBuilder();

  /// Builds a quoted command line for [executable].
  ///
  /// [arguments] are appended after the executable. At least one argument must
  /// contain `%1` so Windows passes the invoked URL to the application.
  String build({
    required String executable,
    List<String> arguments = const [_urlPlaceholder],
  }) {
    if (executable.isEmpty) {
      throw ArgumentError.value(
        executable,
        'executable',
        'must not be empty',
      );
    }
    if (!arguments.any((argument) => argument.contains(_urlPlaceholder))) {
      throw ArgumentError.value(
        arguments,
        'arguments',
        'must contain at least one "$_urlPlaceholder" placeholder',
      );
    }

    final quotedArguments = arguments.map(_quote).join(' ');

    return '${_quote(executable)} $quotedArguments';
  }

  /// Quotes [value] following the `CommandLineToArgvW` parsing rules, where
  /// backslashes are only special when they precede a double quote.
  String _quote(String value) {
    // Double backslashes before quotes and at the end so they stay literal.
    final doubled = value.replaceAllMapped(_backslashesBeforeQuoteOrEnd, (match) => match[0]! * 2);

    return '"${doubled.replaceAll('"', r'\"')}"';
  }
}
