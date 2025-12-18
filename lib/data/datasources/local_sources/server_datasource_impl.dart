import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/model/raw/add_server_request.dart';
import 'package:trusttunnel/data/model/raw/raw_server.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';

/// {@template server_data_source_impl}
/// Drift-backed implementation of [ServerDataSource].
///
/// Server records are stored in the `servers` table, while DNS server entries
/// are stored in `dnsServers` and linked by `serverId`.
///
/// ### Consistency notes
/// Some operations update multiple tables (server row + DNS rows). If strict
/// atomicity is required, wrap these calls in a Drift transaction at a higher
/// layer.
/// {@endtemplate}
class ServerDataSourceImpl implements ServerDataSource {
  /// Drift database used for persistence.
  final db.AppDatabase database;

  /// {@macro server_data_source_impl}
  ServerDataSourceImpl({
    required this.database,
  });

  /// {@macro server_data_source_add_new_server}
  @override
  Future<RawServer> addNewServer({required AddServerRequest request}) async {
    final id = await database.servers.insertOnConflictUpdate(
      db.ServersCompanion.insert(
        ipAddress: request.ipAddress,
        name: request.name,
        domain: request.domain,
        login: request.username,
        password: request.password,
        vpnProtocolId: request.vpnProtocol.value,
        routingProfileId: request.routingProfileId,
      ),
    );

    await database.dnsServers.insertAll(
      request.dnsServers.map(
        (s) => db.DnsServersCompanion.insert(
          serverId: id,
          data: s,
        ),
      ),
    );

    return RawServer(
      id: id,
      name: request.name,
      ipAddress: request.ipAddress,
      domain: request.domain,
      username: request.username,
      password: request.password,
      vpnProtocol: request.vpnProtocol,
      routingProfileId: request.routingProfileId,
      dnsServers: request.dnsServers,
    );
  }

  /// {@macro server_data_source_get_all_servers}
  ///
  /// This method loads server rows first, then loads DNS rows for all servers,
  /// and finally assembles [RawServer] instances.
  @override
  Future<List<RawServer>> getAllServers() async {
    final serversRows = await database.select(database.servers).get();
    if (serversRows.isEmpty) return [];

    final serverIds = serversRows.map((s) => s.id).toList();

    final dnsRows = await _loadDnsAddresses({...serverIds});

    final dnsByServer = <int, List<String>>{};
    for (final d in dnsRows) {
      (dnsByServer[d.serverId] ??= <String>[]).add(d.data);
    }

    return serversRows
        .map(
          (e) => RawServer(
            id: e.id,
            name: e.name,
            ipAddress: e.ipAddress,
            domain: e.domain,
            username: e.login,
            password: e.password,
            vpnProtocol: VpnProtocol.values.firstWhere((p) => p.value == e.vpnProtocolId),
            dnsServers: dnsByServer[e.id] ?? const <String>[],
            routingProfileId: e.routingProfileId,
            selected: e.selected,
          ),
        )
        .toList();
  }

  /// {@macro server_data_source_set_selected_server_id}
  @override
  Future<void> setSelectedServerId({required int id}) async {
    final updatePrevious = database.servers.update()..where((e) => e.selected.equals(true));
    final updateCurrent = database.servers.update()..where((e) => e.id.equals(id));

    await updatePrevious.write(const db.ServersCompanion(selected: Value(false)));
    await updateCurrent.write(const db.ServersCompanion(selected: Value(true)));
  }

  /// {@macro server_data_source_remove_server}
  @override
  Future<void> removeServer({required int serverId}) => database.servers.deleteWhere((e) => e.id.equals(serverId));

  /// {@macro server_data_source_set_new_server}
  ///
  /// DNS entries are fully replaced: existing rows are deleted and then the new
  /// list is inserted.
  @override
  Future<void> setNewServer({required int id, required AddServerRequest request}) async {
    final update = database.servers.update()..where((e) => e.id.equals(id));

    await database.dnsServers.deleteWhere((e) => e.serverId.equals(id));
    await database.dnsServers.insertAll(
      request.dnsServers.map(
        (s) => db.DnsServersCompanion.insert(
          serverId: id,
          data: s,
        ),
      ),
    );

    await update.write(
      db.ServersCompanion(
        name: Value(request.name),
        ipAddress: Value(request.ipAddress),
        domain: Value(request.domain),
        login: Value(request.username),
        password: Value(request.password),
        vpnProtocolId: Value(request.vpnProtocol.value),
        routingProfileId: Value(request.routingProfileId),
      ),
    );
  }

  /// {@macro server_data_source_get_server_by_id}
  ///
  /// Throws a generic [Exception] when the server row does not exist.
  @override
  Future<RawServer> getServerById({required int id}) async {
    final server = await (database.select(database.servers)..where((e) => e.id.equals(id))).getSingleOrNull();
    if (server == null) {
      throw Exception('Server not found');
    }
    final dnsServers = await _loadDnsAddresses({id});

    return RawServer(
      id: server.id,
      name: server.name,
      ipAddress: server.ipAddress,
      domain: server.domain,
      username: server.login,
      password: server.password,
      vpnProtocol: VpnProtocol.values.firstWhere((p) => p.value == server.vpnProtocolId),
      dnsServers: dnsServers.map((e) => e.data).toList(),
      routingProfileId: server.routingProfileId,
      selected: server.selected,
    );
  }

  /// Loads DNS server rows for the given server ids.
  ///
  /// Rows are returned in insertion order (ascending by row id).
  Future<List<db.DnsServer>> _loadDnsAddresses(Set<int> serversIds) async {
    final select = database.select(database.dnsServers)
      ..where((r) => r.serverId.isIn(serversIds))
      ..orderBy(
        [
          (r) => OrderingTerm.asc(
            r.rowId,
          ),
        ],
      );

    return select.get();
  }
}
