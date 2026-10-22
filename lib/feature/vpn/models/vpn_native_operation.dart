/// The single repository mutation awaiting its reply, separate from a replaceable user command.
/// Its completion allows the next operation; native status confirms the connection outcome.
enum VpnNativeOperation {
  /// Submit a VPN start with the prepared configuration.
  start,

  /// Submit a stop without assuming that native disconnection has already occurred.
  stop,

  /// Synchronize the saved system configuration without starting a disconnected VPN.
  updateConfiguration,

  /// Remove the system configuration after the server list becomes empty.
  deleteConfiguration,
}
