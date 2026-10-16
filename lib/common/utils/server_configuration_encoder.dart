import 'dart:convert';
import 'dart:typed_data';

import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';

/// Encodes the version 1 TrustTunnel TLV payload as unpadded base64url.
class ServerConfigurationEncoder extends Converter<ServerData, String> {
  const ServerConfigurationEncoder();

  @override
  String convert(ServerData input) {
    final anyValueIsEmpty = [
      input.domain,
      input.ipAddress,
      input.username,
      input.password,
    ].any((value) => value.isEmpty);
    if (anyValueIsEmpty) {
      throw const FormatException('Missing required server configuration field');
    }

    final payload = BytesBuilder();
    void field(int tag, List<int> value) {
      payload
        ..add(_varInt(tag))
        ..add(_varInt(value.length))
        ..add(value);
    }

    void text(int tag, String value) => field(tag, utf8.encode(value));

    // Version 1 is supported by the existing import SDK on all platforms.
    field(0x00, [1]);
    text(0x01, input.domain);
    text(0x05, input.username);
    text(0x06, input.password);
    text(0x02, input.ipAddress);

    // Preserve the full Client Random value, including its optional mask.
    final prefix = input.tlsPrefix;
    if (prefix != null && prefix.isNotEmpty) {
      text(0x0b, prefix);
    }
    final sni = input.customSni;
    if (sni != null && sni.isNotEmpty) {
      text(0x03, sni);
    }
    if (!input.ipv6) {
      field(0x04, [0]);
    }

    final certificate = input.certificate;
    if (certificate != null) {
      field(0x08, _certificateBytes(certificate.data));
    }
    if (input.vpnProtocol == VpnProtocol.quic) {
      field(0x09, [2]);
    }
    text(0x0c, input.name);

    if (input.dnsServers.isNotEmpty) {
      final dns = BytesBuilder();
      for (final address in input.dnsServers) {
        final bytes = utf8.encode(address);
        dns
          ..add(_varInt(bytes.length))
          ..add(bytes);
      }
      field(0x0d, dns.takeBytes());
    }

    return base64Url.encode(payload.takeBytes()).replaceAll('=', '');
  }

  /// QUIC/TLS variable-length integer, in network byte order.
  List<int> _varInt(int value) {
    final (length, prefix) = switch (value) {
      < 0x40 => (1, 0x00),
      < 0x4000 => (2, 0x40),
      < 0x40000000 => (4, 0x80),
      < 0x4000000000000000 => (8, 0xc0),
      _ => throw const FormatException('Configuration field is too long'),
    };
    final bytes = List<int>.generate(length, (index) => (value >> (8 * (length - index - 1))) & 0xff);
    bytes[0] |= prefix;

    return bytes;
  }

  List<int> _certificateBytes(String pem) {
    final blocks = RegExp(
      r'-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+/=\s]+?)\s*-----END CERTIFICATE-----',
    ).allMatches(pem);
    if (blocks.isEmpty) {
      throw const FormatException('Invalid PEM certificate');
    }

    final bytes = BytesBuilder();
    for (final block in blocks) {
      final der = base64.decode(block.group(1)!.replaceAll(RegExp(r'\s'), ''));
      if (der.isEmpty) {
        throw const FormatException('Empty certificate');
      }

      bytes.add(der);
    }

    return bytes.takeBytes();
  }
}
