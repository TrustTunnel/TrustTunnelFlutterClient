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

    final valid = ValidationUtils.tryParseDomain(sni!) != null;

    if (!valid) {
      return _getFieldWrongValue(PresentationFieldName.sni);
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

  PresentationField? _validateDnsServers(List<String> dnsServers) {
    final fieldName = PresentationFieldName.dnsServers;

    if (dnsServers.isEmpty) {
      return _getRequiredField(fieldName);
    }

    for (final dnsServer in dnsServers) {
      if (!ValidationUtils.validateDnsServer(dnsServer)) {
        return _getFieldWrongValue(fieldName);
      }
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
