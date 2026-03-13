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
}

class ServerDetailsServiceImpl implements ServerDetailsService {
  @override
  List<PresentationField> validateData({
    required ServerData data,
    Set<String> otherServersNames = const {},
  }) {
    final List<PresentationField> fields = [];
    final serverNameValidationResult = _validateServerName(
      data.name,
      otherServersNames,
    );
    if (serverNameValidationResult != null) {
      fields.add(serverNameValidationResult);
    }

    final ipAddressValidationResult = _validateIpAddress(data.ipAddress);
    if (ipAddressValidationResult != null) {
      fields.add(ipAddressValidationResult);
    }

    final domainValidationResult = _validateDomain(data.domain);
    if (domainValidationResult != null) {
      fields.add(domainValidationResult);
    }

    final sniValidationResult = _validateSni(data.customSni);
    if (sniValidationResult != null) {
      fields.add(sniValidationResult);
    }

    final usernameValidationResult = _validateUsername(data.username);
    if (usernameValidationResult != null) {
      fields.add(usernameValidationResult);
    }

    final passwordValidationResult = _validatePassword(data.password);
    if (passwordValidationResult != null) {
      fields.add(passwordValidationResult);
    }

    final dnsServersValidationResult = _validateDnsServers(data.dnsServers);
    if (dnsServersValidationResult != null) {
      fields.add(dnsServersValidationResult);
    }

    if (data.tlsPrefix != null) {
      final clientRandomValidationResult = validateClientRandom(data.tlsPrefix!);
      if (clientRandomValidationResult != null) {
        fields.add(clientRandomValidationResult);
      }
    }

    return fields;
  }

  PresentationField? validateClientRandom(String value) {
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

  PresentationField? _validateServerName(String serverName, Set<String> otherServerNames) {
    final fieldName = PresentationFieldName.serverName;
    if (serverName.trim().isEmpty) {
      return _getRequiredField(fieldName);
    }
    if (otherServerNames.map((e) => e.trim().toLowerCase()).contains(serverName.trim().toLowerCase())) {
      return _getAlreadyExistsField(fieldName);
    }

    return null;
  }

  PresentationField? _validateIpAddress(String ipAddress) {
    final validationResult = ValidationUtils.validateIpAddress(ipAddress);

    return validationResult ? null : _getFieldWrongValue(PresentationFieldName.ipAddress);
  }

  PresentationField? _validateSni(String? sni) {
    if (sni?.trim().isEmpty ?? true) {
      return null;
    }

    final valid = ValidationUtils.tryParseDomain(sni!) != null;

    if (!valid) {
      return _getFieldWrongValue(PresentationFieldName.sni);
    }

    return null;
  }

  PresentationField? _validateDomain(String domain) {
    final fieldName = PresentationFieldName.domain;
    if (domain.isEmpty) {
      return _getRequiredField(fieldName);
    }
    final valid =
        ValidationUtils.validateIpAddress(domain, allowPort: false) || ValidationUtils.tryParseDomain(domain) != null;

    if (!valid) {
      return _getFieldWrongValue(fieldName);
    }

    return null;
  }

  PresentationField? _validateUsername(String username) {
    final fieldName = PresentationFieldName.userName;
    if (username.isEmpty) {
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

  PresentationField? _validateDnsServers(List<String> dnsServers) {
    final fieldName = PresentationFieldName.dnsServers;

    if (dnsServers.isEmpty) {
      return _getRequiredField(fieldName);
    }
    final allowableRegex = RegExp(ValidationUtils.allowableStartRegex);

    for (var dnsServer in dnsServers) {
      final rawServer = dnsServer;
      if (allowableRegex.hasMatch(dnsServer)) {
        final parsedUri = Uri.tryParse(dnsServer);
        if (parsedUri != null && parsedUri.host.isNotEmpty) {
          dnsServer = parsedUri.host + (parsedUri.hasPort ? ':${parsedUri.port}' : '');
        }
      }

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

      final invalidPort = port != null && parsedPort == null;

      if (invalidPort) {
        return _getFieldWrongValue(fieldName);
      }

      if (parsedPort != null)
        if (parsedPort < 1 || parsedPort > 65535) {
          return _getFieldWrongValue(fieldName);
        }

      final isValidURI = Uri.tryParse(rawServer)?.hasAbsolutePath ?? false;

      if (!isValidURI &&
          !ValidationUtils.validateIpAddress(dnsServer, allowPort: false) &&
          ValidationUtils.tryParseDomain(dnsServer) == null) {
        return _getFieldWrongValue(fieldName);
      }
    }

    return null;
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
