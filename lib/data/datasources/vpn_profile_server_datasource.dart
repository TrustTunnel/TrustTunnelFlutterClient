/// Stores the server ID of the VPN profile that the system keeps for this app.
///
/// The profile outlives the app session: the system can start the VPN from it
/// without the app, so the app keeps the profile's server ID separately to
/// restore which server a system-initiated connection uses.
abstract class VpnProfileServerDataSource {
  /// The server ID of the saved VPN profile, or `null` if it is unknown.
  Future<String?> getServerId();

  /// Replaces the saved server ID, or removes it when [serverId] is `null`.
  ///
  /// Returns whether the storage accepted the write. Storage errors complete
  /// the returned future with an error.
  Future<bool> setServerId(String? serverId);
}
