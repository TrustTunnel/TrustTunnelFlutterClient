import 'dart:convert';

import 'package:trusttunnel/common/utils/tls_profile_encoder.dart';
import 'package:trusttunnel/common/utils/upstream_protocol_encoder.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/model/tls_authentication_type.dart';
import 'package:vpn_plugin/models/endpoint.dart';

class ServerEndpointEncoder extends Converter<ServerData, Endpoint> {
  final List<String> exclusions;

  const ServerEndpointEncoder({this.exclusions = const []});

  @override
  Endpoint convert(ServerData server) => Endpoint(
    name: server.name,
    hostName: server.domain,
    hasIpv6: server.ipv6,
    tlsProfile: const TlsProfileEncoder().convert(server.tlsFingerprint),
    certificate: server.certificate?.data ?? '',
    clientRandom: server.tlsAuthenticationType == TlsAuthenticationType.clientRandom ? (server.tlsPrefix ?? '') : '',
    clientRandomAuthKey: server.tlsAuthenticationType == TlsAuthenticationType.clientRandomAuthKey
        ? (server.clientRandomAuthKey ?? '')
        : '',
    customSni: server.customSni ?? '',
    username: server.username,
    password: server.password,
    addresses: [server.ipAddress],
    exclusions: exclusions,
    dnsUpStreams: server.dnsServers,
    upStreamProtocol: UpStreamProtocolEncoder().convert(server.vpnProtocol),
  );
}
