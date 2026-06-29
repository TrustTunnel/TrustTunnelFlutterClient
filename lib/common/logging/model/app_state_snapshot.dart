import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/logging/model/logging_settings.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/model/certificate.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';

typedef JsonMap = Map<String, Object?>;

@immutable
final class AppStateSnapshot {
  final AppMetadataSnapshot app;
  final VpnStatusSnapshot vpn;
  final DatabaseSnapshot database;
  final LoggingConfigurationSnapshot logging;
  final ServersSnapshot servers;
  final RoutingProfilesSnapshot routingProfiles;
  final ExcludedRoutesSnapshot excludedRoutes;
  final QueryLogSnapshot queryLog;

  const AppStateSnapshot({
    required this.app,
    required this.vpn,
    required this.database,
    required this.logging,
    required this.servers,
    required this.routingProfiles,
    required this.excludedRoutes,
    required this.queryLog,
  });

  JsonMap toJson() => {
    'app': app.toJson(),
    'vpn': vpn.toJson(),
    'database': database.toJson(),
    'logging': logging.toJson(),
    'servers': servers.toJson(),
    'routingProfiles': routingProfiles.toJson(),
    'excludedRoutes': excludedRoutes.toJson(),
    'queryLog': queryLog.toJson(),
  };
}

@immutable
final class AppMetadataSnapshot {
  final String name;
  final String version;
  final String build;
  final String platform;

  const AppMetadataSnapshot({
    required this.name,
    required this.version,
    required this.build,
    required this.platform,
  });

  JsonMap toJson() => {
    'name': name,
    'version': version,
    'build': build,
    'platform': platform,
  };
}

@immutable
final class VpnStatusSnapshot {
  final String state;

  const VpnStatusSnapshot({
    required this.state,
  });

  JsonMap toJson() => {
    'state': state,
  };
}

@immutable
final class DatabaseSnapshot {
  final int schemaVersion;
  final Object fileSize;

  const DatabaseSnapshot({
    required this.schemaVersion,
    required this.fileSize,
  });

  JsonMap toJson() => {
    'schemaVersion': schemaVersion,
    'fileSize': fileSize,
  };
}

@immutable
final class LoggingConfigurationSnapshot {
  final String level;
  final String securityType;

  const LoggingConfigurationSnapshot({
    required this.level,
    required this.securityType,
  });

  factory LoggingConfigurationSnapshot.fromSettings(LoggingSettings settings) => LoggingConfigurationSnapshot(
    level: settings.level.value,
    securityType: settings.securityType.value,
  );

  JsonMap toJson() => {
    'level': level,
    'securityType': securityType,
  };
}

@immutable
final class ServersSnapshot {
  final int count;
  final SelectedServerSnapshot? selected;
  final List<ServerSnapshot>? items;

  const ServersSnapshot({
    required this.count,
    required this.selected,
    required this.items,
  });

  factory ServersSnapshot.fromServers(
    List<Server> servers, {
    required Server? selectedServer,
    required bool includeSensitiveData,
  }) => ServersSnapshot(
    count: servers.length,
    selected: selectedServer == null
        ? null
        : SelectedServerSnapshot.fromServer(
            selectedServer,
            includeSensitiveData: includeSensitiveData,
          ),
    items: includeSensitiveData ? servers.map(ServerSnapshot.fromServer).toList() : null,
  );

  JsonMap toJson() => {
    'count': count,
    'selected': selected?.toJson(),
    if (items != null) 'items': items!.map((item) => item.toJson()).toList(),
  };
}

@immutable
final class SelectedServerSnapshot {
  final String id;
  final String name;
  final String vpnProtocol;
  final String routingProfileId;
  final ServerSnapshot? fullServer;

  const SelectedServerSnapshot({
    required this.id,
    required this.name,
    required this.vpnProtocol,
    required this.routingProfileId,
    required this.fullServer,
  });

  factory SelectedServerSnapshot.fromServer(
    Server server, {
    required bool includeSensitiveData,
  }) => SelectedServerSnapshot(
    id: server.id,
    name: server.serverData.name,
    vpnProtocol: server.serverData.vpnProtocol.name,
    routingProfileId: server.serverData.routingProfileId,
    fullServer: includeSensitiveData ? ServerSnapshot.fromServer(server) : null,
  );

  JsonMap toJson() =>
      fullServer?.toJson() ??
      {
        'id': id,
        'name': name,
        'vpnProtocol': vpnProtocol,
        'routingProfileId': routingProfileId,
      };
}

@immutable
final class ServerSnapshot {
  final String id;
  final String name;
  final String ipAddress;
  final String domain;
  final String? customSni;
  final String username;
  final String password;
  final String vpnProtocol;
  final List<String> dnsServers;
  final String routingProfileId;
  final bool selected;
  final bool ipv6;
  final String? tlsPrefix;
  final CertificateSnapshot? certificate;

  const ServerSnapshot({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.customSni,
    required this.username,
    required this.password,
    required this.vpnProtocol,
    required this.dnsServers,
    required this.routingProfileId,
    required this.selected,
    required this.ipv6,
    required this.tlsPrefix,
    required this.certificate,
  });

  factory ServerSnapshot.fromServer(Server server) => ServerSnapshot(
    id: server.id,
    name: server.serverData.name,
    ipAddress: server.serverData.ipAddress,
    domain: server.serverData.domain,
    customSni: server.serverData.customSni,
    username: server.serverData.username,
    password: server.serverData.password,
    vpnProtocol: server.serverData.vpnProtocol.name,
    dnsServers: server.serverData.dnsServers,
    routingProfileId: server.serverData.routingProfileId,
    selected: server.serverData.selected,
    ipv6: server.serverData.ipv6,
    tlsPrefix: server.serverData.tlsPrefix,
    certificate: server.serverData.certificate == null
        ? null
        : CertificateSnapshot.fromCertificate(server.serverData.certificate!),
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'ipAddress': ipAddress,
    'domain': domain,
    'customSni': customSni,
    'username': username,
    'password': password,
    'vpnProtocol': vpnProtocol,
    'dnsServers': dnsServers,
    'routingProfileId': routingProfileId,
    'selected': selected,
    'ipv6': ipv6,
    'tlsPrefix': tlsPrefix,
    'certificate': certificate?.toJson(),
  };
}

@immutable
final class CertificateSnapshot {
  final String name;
  final String data;

  const CertificateSnapshot({
    required this.name,
    required this.data,
  });

  factory CertificateSnapshot.fromCertificate(Certificate certificate) => CertificateSnapshot(
    name: certificate.name,
    data: certificate.data,
  );

  JsonMap toJson() => {
    'name': name,
    'data': data,
  };
}

@immutable
final class RoutingProfilesSnapshot {
  final int count;
  final List<RoutingProfileSnapshot> items;

  const RoutingProfilesSnapshot({
    required this.count,
    required this.items,
  });

  factory RoutingProfilesSnapshot.fromProfiles(
    List<RoutingProfile> profiles, {
    required bool includeRules,
  }) => RoutingProfilesSnapshot(
    count: profiles.length,
    items: profiles
        .map(
          (profile) => RoutingProfileSnapshot.fromProfile(
            profile,
            includeRules: includeRules,
          ),
        )
        .toList(),
  );

  JsonMap toJson() => {
    'count': count,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

@immutable
final class RoutingProfileSnapshot {
  final String id;
  final String name;
  final String mode;
  final int bypassRulesCount;
  final int vpnRulesCount;
  final List<String>? bypassRules;
  final List<String>? vpnRules;

  const RoutingProfileSnapshot({
    required this.id,
    required this.name,
    required this.mode,
    required this.bypassRulesCount,
    required this.vpnRulesCount,
    required this.bypassRules,
    required this.vpnRules,
  });

  factory RoutingProfileSnapshot.fromProfile(
    RoutingProfile profile, {
    required bool includeRules,
  }) => RoutingProfileSnapshot(
    id: profile.id,
    name: profile.data.name,
    mode: profile.data.defaultMode.name,
    bypassRulesCount: profile.data.bypassRules.length,
    vpnRulesCount: profile.data.vpnRules.length,
    bypassRules: includeRules ? profile.data.bypassRules : null,
    vpnRules: includeRules ? profile.data.vpnRules : null,
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'mode': mode,
    'bypassRulesCount': bypassRulesCount,
    'vpnRulesCount': vpnRulesCount,
    if (bypassRules != null) 'bypassRules': bypassRules,
    if (vpnRules != null) 'vpnRules': vpnRules,
  };
}

@immutable
final class ExcludedRoutesSnapshot {
  final int count;
  final List<String>? items;

  const ExcludedRoutesSnapshot({
    required this.count,
    required this.items,
  });

  factory ExcludedRoutesSnapshot.fromRoutes(
    List<String> routes, {
    required bool includeItems,
  }) => ExcludedRoutesSnapshot(
    count: routes.length,
    items: includeItems ? routes : null,
  );

  JsonMap toJson() => {
    'count': count,
    if (items != null) 'items': items,
  };
}

@immutable
final class QueryLogSnapshot {
  final int count;
  final QueryLogTimeRangeSnapshot timeRange;
  final List<QueryLogEntrySnapshot>? items;

  const QueryLogSnapshot({
    required this.count,
    required this.timeRange,
    required this.items,
  });

  factory QueryLogSnapshot.fromRows(
    List<db.VpnRequest> rows, {
    required bool includeItems,
  }) {
    DateTime? from;
    DateTime? to;
    for (final row in rows) {
      final date = DateTime.tryParse(row.zonedDateTime);
      if (date == null) {
        continue;
      }
      if (from == null || date.isBefore(from)) {
        from = date;
      }
      if (to == null || date.isAfter(to)) {
        to = date;
      }
    }

    return QueryLogSnapshot(
      count: rows.length,
      timeRange: QueryLogTimeRangeSnapshot(
        from: from?.toIso8601String(),
        to: to?.toIso8601String(),
      ),
      items: includeItems ? rows.map(QueryLogEntrySnapshot.fromRow).toList() : null,
    );
  }

  JsonMap toJson() => {
    'count': count,
    'timeRange': timeRange.toJson(),
    if (items != null) 'items': items!.map((item) => item.toJson()).toList(),
  };
}

@immutable
final class QueryLogTimeRangeSnapshot {
  final String? from;
  final String? to;

  const QueryLogTimeRangeSnapshot({
    required this.from,
    required this.to,
  });

  JsonMap toJson() => {
    'from': from,
    'to': to,
  };
}

@immutable
final class QueryLogEntrySnapshot {
  final String time;
  final String protocol;
  final Object decision;
  final String source;
  final String? sourcePort;
  final String destination;
  final String? destinationPort;
  final String? domain;

  const QueryLogEntrySnapshot({
    required this.time,
    required this.protocol,
    required this.decision,
    required this.source,
    required this.sourcePort,
    required this.destination,
    required this.destinationPort,
    required this.domain,
  });

  factory QueryLogEntrySnapshot.fromRow(db.VpnRequest row) => QueryLogEntrySnapshot(
    time: row.zonedDateTime,
    protocol: row.protocolName,
    decision: row.decision,
    source: row.sourceIpAddress,
    sourcePort: row.sourcePort,
    destination: row.destinationIpAddress,
    destinationPort: row.destinationPort,
    domain: row.domain,
  );

  JsonMap toJson() => {
    'time': time,
    'protocol': protocol,
    'decision': decision,
    'source': source,
    'sourcePort': sourcePort,
    'destination': destination,
    'destinationPort': destinationPort,
    'domain': domain,
  };
}

extension AppStateSnapshotLookup on Iterable<Server> {
  Server? get selectedServer => firstWhereOrNull((server) => server.serverData.selected);
}
