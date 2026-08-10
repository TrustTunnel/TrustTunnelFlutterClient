/// {@template vpn_configuration_log_level}
/// Defines the available log levels for VPN configuration.
///
/// Log levels control the verbosity of logging in the VPN system:
/// - [error]: Error messages only (lowest enabled verbosity)
/// - [info]: Standard information messages
/// - [debug]: Detailed information for debugging purposes
/// {@endtemplate}
enum VpnConfigurationLogLevel {
  error,
  info,
  debug,
}
