import 'package:drift/drift.dart';
import 'package:vpn/data/database/app_database.dart' as db;
import 'package:vpn/data/datasources/server_datasource.dart';
import 'package:vpn/data/model/raw/add_server_request.dart';
import 'package:vpn/data/model/raw/raw_server.dart';
import 'package:vpn/data/model/vpn_protocol.dart';

class ServerDataSourceImpl implements ServerDataSource {
  final db.AppDatabase database;

  ServerDataSourceImpl({
    required this.database,
  });

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

  @override
  Future<void> setSelectedServerId({required int id}) async {
    final updatePrevious = database.servers.update()..where((e) => e.selected.equals(true));
    final updateCurrent = database.servers.update()..where((e) => e.id.equals(id));

    await updatePrevious.write(const db.ServersCompanion(selected: Value(false)));
    await updateCurrent.write(const db.ServersCompanion(selected: Value(true)));
  }

  @override
  Future<void> removeServer({required int serverId}) => database.servers.deleteWhere((e) => e.id.equals(serverId));

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
    );
  }

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
