/// Builds the command line stored in a Windows URL protocol registration.
final class ProtocolCommandBuilder {
  /// The placeholder Windows replaces with the invoked URL.
  static const String _urlPlaceholder = '%1';

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
      throw ArgumentError.value(executable, 'executable', 'must not be empty');
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

  String _quote(String value) => '"${value.replaceAll('"', r'\"')}"';
}
