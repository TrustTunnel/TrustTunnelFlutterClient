import 'package:trusttunnel/common/error/model/enum/presentation_field_error_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/utils/validation_utils.dart';
import 'package:trusttunnel/data/model/server_data.dart';

abstract class ServerDetailsService {
  List<PresentationField> validateData({
    required ServerData data,
    Set<String> otherServersNames = const {},
  });

  String fallbackDuplicateNames(String baseName, Set<String> otherNames);
}

class ServerDetailsServiceImpl implements ServerDetailsService {
  @override
  List<PresentationField> validateData({
    required ServerData data,
    Set<String> otherServersNames = const {},
  }) {
    final List<PresentationField> fields = [];

    _addIfNotNull(
      fields,
      _validateServerName(
        data.name,
        otherServersNames,
      ),
    );

    _addIfNotNull(
      fields,
      _validateServerAddress(
        data.ipAddress,
      ),
    );

    _addIfNotNull(
      fields,
      _validateDomain(
        data.domain,
      ),
    );

    _addIfNotNull(
      fields,
      _validateSni(
        data.customSni,
      ),
    );

    _addIfNotNull(
      fields,
      _validateUsername(
        data.username,
      ),
    );

    _addIfNotNull(
      fields,
      _validatePassword(
        data.password,
      ),
    );

    _addIfNotNull(
      fields,
      _validateDnsServers(
        data.dnsServers,
      ),
    );

    if (data.tlsPrefix != null) {
      _addIfNotNull(
        fields,
        _validateClientRandom(
          data.tlsPrefix!,
        ),
      );
    }

    return fields;
  }

  @override
  String fallbackDuplicateNames(String baseName, Set<String> otherNames) {
    final duplicateCandidates = otherNames.where((e) => e.startsWith(baseName));

    for (int i = 1; i < duplicateCandidates.length + 1; i++) {
      final candidate = '$baseName ${i + 1}';
      if (!duplicateCandidates.contains(candidate)) {
        return candidate;
      }
    }

    return baseName;
  }

  PresentationField? _validateClientRandom(String value) {
    final input = value.trim();

    if (input.isEmpty) {
      return null;
    }

    final parts = input.split('/');
    if (parts.length > 2) {
      return _getFieldWrongValue(PresentationFieldName.clientRandom);
    }

    final clientRandom = parts[0];
    final mask = parts.length == 2 ? parts[1] : null;
    final hexRegexp = RegExp(r'^[0-9A-Fa-f]+$');

    if (!hexRegexp.hasMatch(clientRandom)) {
      return _getFieldWrongValue(PresentationFieldName.clientRandom);
    }

    if (mask == null) {
      if (!_isEvenLengthHex(clientRandom)) {
        return _getFieldWrongValue(PresentationFieldName.clientRandomValue);
      }

      return null;
    }

    if (!hexRegexp.hasMatch(mask)) {
      return _getFieldWrongValue(PresentationFieldName.clientRandom);
    }

    if (!_isEvenLengthHex(mask) || !_isEvenLengthHex(clientRandom)) {
      return _getFieldWrongValue(PresentationFieldName.clientRandomMask);
    }

    if (clientRandom.length != mask.length) {
      return _getFieldOutOfBounds(PresentationFieldName.clientRandom);
    }

    return null;
  }

  bool _isEvenLengthHex(String value) => value.isNotEmpty && value.length.isEven;

  PresentationField? _validateServerName(
    String serverName,
    Set<String> otherServerNames,
  ) {
    final fieldName = PresentationFieldName.serverName;
    final normalizedName = serverName.trim();

    if (normalizedName.isEmpty) {
      return _getRequiredField(fieldName);
    }

    final normalizedOtherNames = otherServerNames.map((e) => e.trim().toLowerCase()).toSet();

    if (normalizedOtherNames.contains(normalizedName.toLowerCase())) {
      return _getAlreadyExistsField(fieldName);
    }

    return null;
  }

  PresentationField? _validateServerAddress(String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      return _getRequiredField(PresentationFieldName.ipAddress);
    }

    final valid = ValidationUtils.validateServerAddress(normalizedValue);

    return valid ? null : _getFieldWrongValue(PresentationFieldName.ipAddress);
  }

  PresentationField? _validateSni(String? sni) {
    if (sni?.trim().isEmpty ?? true) {
      return null;
    }

    sni = sni!.trim();

    final valid = ValidationUtils.tryParseDomain(sni) != null;

    if (!valid) {
      return _getFieldWrongValue(PresentationFieldName.sni);
    }

    return null;
  }

  PresentationField? _validateDnsServers(List<String> dnsServers) {
    final fieldName = PresentationFieldName.dnsServers;

    if (dnsServers.join().trim().isEmpty) {
      return null;
    }

    for (var dnsServer in dnsServers) {
      dnsServer = dnsServer.trim();

      if (dnsServer.isEmpty) {
        return _getFieldWrongValue(fieldName);
      }

      // 1. DNS stamp
      if (dnsServer.startsWith('sdns://')) {
        if (!ValidationUtils.validateDnsStamp(dnsServer)) {
          return _getFieldWrongValue(fieldName);
        }
        continue;
      }

      // 2. URI-based DNS
      if (RegExp(r'^(tls:\/\/|https:\/\/|http:\/\/|quic:\/\/|h3:\/\/)').hasMatch(dnsServer)) {
        final parsedUri = Uri.tryParse(dnsServer);
        if (parsedUri == null || parsedUri.host.isEmpty) {
          return _getFieldWrongValue(fieldName);
        }

        dnsServer = parsedUri.host + (parsedUri.hasPort ? ':${parsedUri.port}' : '');
      }

      // 3. host[:port] / ip[:port]
      String? port;
      final divided = dnsServer.split(':');

      if (dnsServer.startsWith('[')) {
        port = divided.removeLast();
        dnsServer = divided.join(':').replaceAll(RegExp(r'[\[\]]'), '');
      } else if (divided.length == 2) {
        port = divided.last;
        dnsServer = divided.first;
      }

      final parsedPort = int.tryParse(port ?? '');
      if (port != null && parsedPort == null) {
        return _getFieldWrongValue(fieldName);
      }

      if (parsedPort != null && (parsedPort < 1 || parsedPort > 65535)) {
        return _getFieldWrongValue(fieldName);
      }

      if (!ValidationUtils.validateIpAddress(dnsServer, allowPort: false) &&
          ValidationUtils.tryParseDomain(dnsServer) == null) {
        return _getFieldWrongValue(fieldName);
      }
    }

    return null;
  }

  PresentationField? _validateDomain(String domain) {
    final fieldName = PresentationFieldName.domain;
    final normalizedDomain = domain.trim();

    if (normalizedDomain.isEmpty) {
      return _getRequiredField(fieldName);
    }

    final valid =
        ValidationUtils.validateIpAddress(normalizedDomain, allowPort: false) ||
        ValidationUtils.parseServerHost(normalizedDomain) != null;

    return valid ? null : _getFieldWrongValue(fieldName);
  }

  PresentationField? _validateUsername(String username) {
    final fieldName = PresentationFieldName.userName;
    if (username.trim().isEmpty) {
      return _getRequiredField(fieldName);
    }

    return null;
  }

  PresentationField? _validatePassword(String password) {
    final fieldName = PresentationFieldName.password;
    if (password.isEmpty) {
      return _getRequiredField(fieldName);
    }

    return null;
  }

  void _addIfNotNull(
    List<PresentationField> fields,
    PresentationField? field,
  ) {
    if (field != null) {
      fields.add(field);
    }
  }

  PresentationField _getRequiredField(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldErrorCode.fieldRequired,
    fieldName: fieldName,
  );

  PresentationField _getAlreadyExistsField(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldErrorCode.alreadyExists,
    fieldName: fieldName,
  );

  PresentationField _getFieldWrongValue(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldErrorCode.fieldWrongValue,
    fieldName: fieldName,
  );

  PresentationField _getFieldOutOfBounds(PresentationFieldName fieldName) => PresentationField(
    code: PresentationFieldErrorCode.outOfBounds,
    fieldName: fieldName,
  );
}
