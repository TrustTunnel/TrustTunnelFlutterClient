import 'package:meta/meta.dart';

/// {@template configuration_log_level}
/// Defines the available log levels for VPN configuration.
///
/// Log levels control the verbosity of logging in the VPN system:
/// - [error]: Error messages only (lowest enabled verbosity)
/// - [info]: Standard information messages
/// - [debug]: Detailed information for debugging purposes
/// - [trace]: Extremely detailed tracing information (highest verbosity)
///
/// The log level determines which messages will be included in logs.
/// Higher verbosity levels include all messages from lower levels.
/// {@endtemplate}
@immutable
enum ConfigurationLogLevel {
  /// Error logging level.
  ///
  /// Includes only error messages. This is the least verbose enabled logging
  /// level.
  error('error'),

  /// Standard information logging level.
  ///
  /// Includes important operational messages and significant events.
  info('info'),

  /// Debug logging level.
  ///
  /// Includes detailed information useful for debugging purposes.
  /// More verbose than [info] but less verbose than [trace].
  debug('debug'),

  /// Trace logging level.
  ///
  /// Includes extremely detailed tracing information.
  /// This is the most verbose logging level and may significantly
  /// impact performance when enabled.
  trace('trace');

  /// The string representation of this log level.
  ///
  /// This value is used when encoding the log level for configuration
  /// purposes or when communicating with platform-specific VPN implementations.
  final String value;

  /// Creates a log level with the specified string [value].
  const ConfigurationLogLevel(this.value);
}
