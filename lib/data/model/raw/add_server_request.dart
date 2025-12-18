import 'package:trusttunnel/data/model/vpn_protocol.dart';

/// {@template add_server_request}
/// Input payload for creating or updating a server record.
///
/// This is a Dart record type used as a lightweight request DTO.
/// It intentionally mirrors the persisted server fields and is typically used
/// by data sources/repositories when writing to storage.
///
/// Field meanings match those in [RawServer] and [Server].
/// {@endtemplate}
typedef AddServerRequest = ({
  /// User-visible server name.
  String name,

  /// Server IP address (IPv4/IPv6 literal).
  String ipAddress,

  /// Server host name used for TLS (SNI / certificate verification).
  String domain,

  /// Username used for authentication.
  String username,

  /// Password used for authentication.
  String password,

  /// Transport protocol used to communicate with the server.
  VpnProtocol vpnProtocol,

  /// Routing profile id to associate with this server.
  int routingProfileId,

  /// DNS upstream addresses associated with this server.
  List<String> dnsServers,
});
