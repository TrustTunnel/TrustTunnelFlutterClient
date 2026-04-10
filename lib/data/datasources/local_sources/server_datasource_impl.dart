import 'package:drift/drift.dart';
import 'package:trusttunnel/common/utils/certificate_encoders.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/model/certificate.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:vpn_plugin/deep_link_manager.dart';
import 'package:vpn_plugin/models/upstream_protocol.dart';

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

  final DeepLinkManager deepLinkManager;

  /// {@macro server_data_source_impl}
  ServerDataSourceImpl({
    required this.database,
    required this.deepLinkManager,
  });

  /// {@macro server_data_source_add_new_server}
  @override
  Future<Server> addNewServer({required ServerData request}) async {
    final id = await database.servers.insertOnConflictUpdate(
      db.ServersCompanion.insert(
        ipAddress: request.ipAddress,
        name: request.name,
        domain: request.domain,
        login: request.username,
        password: request.password,
        vpnProtocolId: request.vpnProtocol.value,
        ipv6Enabled: Value(request.ipv6),
        tlsPrefix: Value(request.tlsPrefix),
        routingProfileId: int.parse(
          request.routingProfileId,
        ),
        customSni: Value(request.customSni),
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

    if (request.certificate != null) {
      await database.certificateTable.insertOnConflictUpdate(
        CertificateEncoder(serverId: id).convert(request.certificate!),
      );
    }

    return Server(
      id: id.toString(),
      serverData: ServerData(
        name: request.name,
        ipAddress: request.ipAddress,
        domain: request.domain,
        username: request.username,
        password: request.password,
        vpnProtocol: request.vpnProtocol,
        routingProfileId: request.routingProfileId,
        dnsServers: request.dnsServers,
        ipv6: request.ipv6,
        certificate: request.certificate,
        tlsPrefix: request.tlsPrefix,
        customSni: request.customSni,
      ),
    );
  }

  /// {@macro server_data_source_get_all_servers}
  ///
  /// This method loads server rows first, then loads DNS rows for all servers,
  /// and finally assembles [RawServer] instances.
  @override
  Future<List<Server>> getAllServers() async {
    final serversRows = await database.select(database.servers).get();
    if (serversRows.isEmpty) return [];

    final certs = await database.select(database.certificateTable).get();

    final certsMap = {for (final c in certs) c.serverId: c};

    final serverIds = serversRows.map((s) => s.id).toList();

    final dnsRows = await _loadDnsAddresses({
      ...serverIds.map(
        (e) => e.toString(),
      ),
    });

    final dnsByServer = <int, List<String>>{};
    for (final d in dnsRows) {
      (dnsByServer[d.serverId] ??= <String>[]).add(d.data);
    }

    return serversRows.map(
      (e) {
        final rawCert = certsMap[e.id];
        final cert = rawCert == null ? null : _parseCert(rawCert);

        return Server(
          id: e.id.toString(),
          serverData: ServerData(
            name: e.name,
            ipAddress: e.ipAddress,
            domain: e.domain,
            username: e.login,
            password: e.password,
            vpnProtocol: VpnProtocol.values.firstWhere((p) => p.value == e.vpnProtocolId),
            dnsServers: dnsByServer[e.id] ?? const <String>[],
            routingProfileId: e.routingProfileId.toString(),
            certificate: cert,
            tlsPrefix: e.tlsPrefix,
            ipv6: e.ipv6Enabled,
            selected: e.selected,
            customSni: e.customSni,
          ),
        );
      },
    ).toList();
  }

  /// {@macro server_data_source_set_selected_server_id}
  @override
  Future<void> setSelectedServerId({required String? id}) async {
    final updatePrevious = database.servers.update()..where((e) => e.selected.equals(true));

    await updatePrevious.write(const db.ServersCompanion(selected: Value(false)));

    if (id != null) {
      final updateCurrent = database.servers.update()..where((e) => e.id.equals(int.parse(id)));
      await updateCurrent.write(const db.ServersCompanion(selected: Value(true)));
    }
  }

  /// {@macro server_data_source_remove_server}
  @override
  Future<void> removeServer({required String serverId}) => database.servers.deleteWhere(
    (e) => e.id.equals(
      int.parse(serverId),
    ),
  );

  /// {@macro server_data_source_set_new_server}
  ///
  /// DNS entries are fully replaced: existing rows are deleted and then the new
  /// list is inserted.
  @override
  Future<void> setNewServer({required String id, required ServerData request}) async {
    final parsedId = int.parse(id);

    final update = database.servers.update()..where((e) => e.id.equals(parsedId));

    await database.dnsServers.deleteWhere((e) => e.serverId.equals(parsedId));
    await database.dnsServers.insertAll(
      request.dnsServers.map(
        (s) => db.DnsServersCompanion.insert(
          serverId: parsedId,
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
        routingProfileId: Value(
          int.parse(request.routingProfileId),
        ),
        ipv6Enabled: Value(request.ipv6),
        tlsPrefix: Value(request.tlsPrefix),
        customSni: Value(request.customSni),
      ),
    );

    final cert = request.certificate;

    if (cert != null) {
      await database.certificateTable.insertOnConflictUpdate(
        CertificateEncoder(serverId: parsedId).convert(cert),
      );
    } else {
      await database.certificateTable.deleteWhere((c) => c.serverId.equals(parsedId));
    }
  }

  /// {@macro server_data_source_get_server_by_id}
  ///
  /// Throws a generic [Exception] when the server row does not exist.
  @override
  Future<Server> getServerById({required String id}) async {
    final parsedId = int.parse(id);

    final server = await (database.select(
      database.servers,
    )..where((e) => e.id.equals(parsedId))).getSingleOrNull();

    if (server == null) {
      throw Exception('Server not found');
    }

    final dnsServers = await _loadDnsAddresses({id});

    final cert = await (database.select(
      database.certificateTable,
    )..where((e) => e.serverId.equals(parsedId))).getSingleOrNull();

    return Server(
      id: server.id.toString(),
      serverData: ServerData(
        name: server.name,
        ipAddress: server.ipAddress,
        domain: server.domain,
        username: server.login,
        password: server.password,
        vpnProtocol: VpnProtocol.values.firstWhere((p) => p.value == server.vpnProtocolId),
        dnsServers: dnsServers.map((e) => e.data).toList(),
        routingProfileId: server.routingProfileId.toString(),
        selected: server.selected,
        ipv6: server.ipv6Enabled,
        tlsPrefix: server.tlsPrefix,
        certificate: cert == null ? null : _parseCert(cert),
        customSni: server.customSni,
      ),
    );
  }

  @override
  Future<ServerData> getServerByBase64({
    required String base64,
    required String routingProfileId,
  }) async {
    final configuration = await deepLinkManager.getConfigurationByBase64(base64: base64);

    // Prefer the human-readable name carried by the deep-link payload (TLV
    // tag 0x0C); fall back to the host name so the imported card never shows
    // a blank title for older deep links that omit the field.
    final String displayName = configuration.endpoint.name.isNotEmpty
        ? configuration.endpoint.name
        : configuration.endpoint.hostName;

    return ServerData.empty(
      name: displayName,
      ipAddress: configuration.endpoint.addresses.first,
      domain: configuration.endpoint.hostName,
      username: configuration.endpoint.username,
      password: configuration.endpoint.password,
      // TODO: Create encoder
      // Konstantin Gorynin <k.gorynin@adguard.com>, 09 March 2026
      vpnProtocol: configuration.endpoint.upStreamProtocol == UpStreamProtocol.http2
          ? VpnProtocol.http2
          : VpnProtocol.quic,
      dnsServers: configuration.endpoint.dnsUpStreams,
      routingProfileId: routingProfileId,
      ipv6: configuration.endpoint.hasIpv6,
      tlsPrefix: configuration.endpoint.clientRandom,
      certificate: configuration.endpoint.certificate.isEmpty
          ? null
          : Certificate(
              name: 'certificate.pem',
              data: configuration.endpoint.certificate,
            ),
      customSni: configuration.endpoint.customSni,
    );
  }

  /// Loads DNS server rows for the given server ids.
  ///
  /// Rows are returned in insertion order (ascending by row id).
  Future<List<db.DnsServer>> _loadDnsAddresses(Set<String> serversIds) async {
    final parsedIds = serversIds.map(int.parse).toSet();

    final select = database.select(database.dnsServers)
      ..where((r) => r.serverId.isIn(parsedIds))
      ..orderBy(
        [
          (r) => OrderingTerm.asc(
            r.rowId,
          ),
        ],
      );

    return select.get();
  }

  Certificate _parseCert(db.CertificateTableData input) => const CertificateDecoder().convert(input);
}
