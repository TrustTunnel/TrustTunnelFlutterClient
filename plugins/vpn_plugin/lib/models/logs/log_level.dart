/// {@template log_level}
/// Severity level for a log record emitted by the VPN plugin.
///
/// This is a sealed class hierarchy that supports the standard log levels
/// (`info`, `debug`, `error`, `warn`) as well as custom levels for
/// forward compatibility with future plugin versions.
///
/// Each known level has a dedicated subclass. Unknown levels parsed from
/// log data are represented by [_LogLevelCustom], preserving the original
/// string without throwing.
///
/// ## Parsing
///
/// Use [LogLevel.fromString] to parse a bracketed level string such as
/// `[info]` or `[warn]` into the corresponding [LogLevel] instance:
///
/// ```dart
/// final level = LogLevel.fromString('[debug]');
/// print(level.name); // 'debug'
/// ```
/// {@endtemplate}
sealed class LogLevel {
  /// The lowercase name of this log level (e.g. `info`, `debug`, `warn`).
  final String name;

  /// Creates a [LogLevel] with the given [name].
  const LogLevel({required this.name});

  /// {@template log_level_from_string}
  /// Parses a bracketed log-level string into a [LogLevel] instance.
  ///
  /// Recognised inputs are `[info]`, `[debug]`, `[error]`, and `[warn]`
  /// (case-insensitive). Any other value produces a [_LogLevelCustom]
  /// that preserves the original [s] in its [name] field.
  ///
  /// This method never throws — unknown levels are handled gracefully
  /// to avoid crashes when the VPN plugin emits log levels introduced
  /// in a newer version.
  /// {@endtemplate}
  factory LogLevel.fromString(String s) {
    switch (s.toLowerCase()) {
      case '[info]':
        return const _LogLevelInfo();
      case '[debug]':
        return const _LogLevelDebug();
      case '[error]':
        return const _LogLevelError();
      case '[warn]':
        return const _LogLevelWarn();
      default:
        return _LogLevelCustom(s);
    }
  }
}

/// Informational log level.
///
/// Represents normal operational messages and significant events.
final class _LogLevelInfo extends LogLevel {
  const _LogLevelInfo() : super(name: 'info');
}

/// Debug log level.
///
/// Represents detailed diagnostic information intended for developers.
/// More verbose than [_LogLevelInfo].
final class _LogLevelDebug extends LogLevel {
  const _LogLevelDebug() : super(name: 'debug');
}

/// Error log level.
///
/// Represents error conditions where one or more functionalities
/// are not working as expected.
final class _LogLevelError extends LogLevel {
  const _LogLevelError() : super(name: 'error');
}

/// Warning log level.
///
/// Represents unexpected behaviour that does not prevent the system
/// from continuing normal operation.
final class _LogLevelWarn extends LogLevel {
  const _LogLevelWarn() : super(name: 'warn');
}

/// Fallback log level for unknown or custom level strings.
///
/// Instances of this class are created by [LogLevel.fromString] when
/// the input does not match any known level. The original string is
/// preserved in [name] for diagnostic purposes.
final class _LogLevelCustom extends LogLevel {
  const _LogLevelCustom(String name) : super(name: name);
}
