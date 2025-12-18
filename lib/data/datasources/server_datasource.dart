import 'package:trusttunnel/data/model/raw/add_server_request.dart';
import 'package:trusttunnel/data/model/raw/raw_server.dart';

/// {@template server_data_source}
/// Persistence interface for VPN servers and their related settings.
///
/// A server record typically includes:
/// - connection endpoint data (IP, domain),
/// - credentials,
/// - a selected VPN protocol,
/// - DNS resolver list,
/// - and a reference to a routing profile.
/// {@endtemplate}
abstract class ServerDataSource {
  /// {@template server_data_source_add_new_server}
  /// Creates a server record and persists its DNS server list.
  /// {@endtemplate}
  Future<RawServer> addNewServer({required AddServerRequest request});

  /// {@template server_data_source_get_server_by_id}
  /// Loads a server by id.
  ///
  /// Implementations may throw if the server does not exist.
  /// {@endtemplate}
  Future<RawServer> getServerById({required int id});

  /// {@template server_data_source_get_all_servers}
  /// Loads all servers stored in persistence.
  ///
  /// Returns an empty list if no servers exist.
  /// {@endtemplate}
  Future<List<RawServer>> getAllServers();

  /// {@template server_data_source_set_selected_server_id}
  /// Marks the server with [id] as selected and unselects any previously selected one.
  ///
  /// Implementations should ensure that at most one server is selected at a time.
  /// {@endtemplate}
  Future<void> setSelectedServerId({required int id});

  /// {@template server_data_source_remove_server}
  /// Removes a server record by its identifier.
  /// {@endtemplate}
  Future<void> removeServer({required int serverId});

  /// {@template server_data_source_set_new_server}
  /// Replaces the stored values of an existing server with the provided request.
  ///
  /// Implementations are expected to update both the main server record and its
  /// DNS server list.
  /// {@endtemplate}
  Future<void> setNewServer({required int id, required AddServerRequest request});
}
