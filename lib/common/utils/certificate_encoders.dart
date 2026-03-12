import 'dart:convert';
import 'dart:typed_data';

import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/model/certificate.dart';

class RawCertificateDecoder extends Converter<Uint8List, String> {
  static const _pemBegin = '-----BEGIN CERTIFICATE-----';
  static const _pemEnd = '-----END CERTIFICATE-----';

  const RawCertificateDecoder();

  @override
  String convert(Uint8List input) {
    final text = _tryUtf8(input);

    if (text != null) {
      return _normalizePem(text);
    }

    return _derToPem(input);
  }

  String? _tryUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  String _normalizePem(String pem) {
    final normalizedLines = pem
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final pemBeginRegex = RegExp(r'^-+BEGIN CERTIFICATE-+');
    final pemEndRegex = RegExp(r'-+END CERTIFICATE-+$');

    final beginIndex = normalizedLines.indexWhere((e) => pemBeginRegex.hasMatch(e));
    final endIndex = normalizedLines.indexWhere((e) => pemEndRegex.hasMatch(e));

    if (beginIndex == -1 || endIndex == -1 || endIndex <= beginIndex) {
      throw const FormatException('Invalid PEM certificate');
    }

    final base64Body = normalizedLines.sublist(beginIndex + 1, endIndex).join();

    if (base64Body.isEmpty) {
      throw const FormatException('Empty PEM certificate body');
    }

    final wrappedBody = _splitByLength(base64Body, 64);

    return '$_pemBegin\n$wrappedBody\n$_pemEnd';
  }

  String _derToPem(Uint8List derBytes) {
    final base64Body = base64Encode(derBytes);
    final wrappedBody = _splitByLength(base64Body, 64);

    return '$_pemBegin\n$wrappedBody\n$_pemEnd';
  }

  String _splitByLength(String value, int chunkSize) {
    final buffer = StringBuffer();

    for (var i = 0; i < value.length; i += chunkSize) {
      final end = (i + chunkSize < value.length) ? i + chunkSize : value.length;
      buffer.write('${value.substring(i, end)}\n');
    }

    return buffer.toString();
  }
}

class CertificateDecoder extends Converter<db.CertificateTableData, Certificate> {
  const CertificateDecoder();

  @override
  Certificate convert(db.CertificateTableData input) => Certificate(
    name: input.name,
    data: input.data,
  );
}

class CertificateEncoder extends Converter<Certificate, db.CertificateTableData> {
  final int serverId;

  const CertificateEncoder({
    required this.serverId,
  });

  @override
  db.CertificateTableData convert(
    Certificate input,
  ) => db.CertificateTableData(
    name: input.name,
    data: input.data,
    serverId: serverId,
  );
}
