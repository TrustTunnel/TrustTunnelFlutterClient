import 'package:trusttunnel/common/error/model/enum/presentation_field_error_code.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/utils/validation_utils.dart';
import 'package:trusttunnel/data/model/raw/add_server_request.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/feature/server/server_details/model/server_details_data.dart';

abstract class ServerDetailsService {
  List<PresentationField> validateData({
    required ServerDetailsData data,
    Set<String> otherServersNames = const {},
  });

  AddServerRequest toAddServerRequest({required ServerDetailsData data});

  ServerDetailsData toServerDetailsData({required Server server});
}

class ServerDetailsServiceImpl implements ServerDetailsService {
  @override
  List<PresentationField> validateData({
    required ServerDetailsData data,
    Set<String> otherServersNames = const {},
  }) {
    final fields = <PresentationField>[];

    _addIfNotNull(
      fields,
      _validateServerName(data.serverName, otherServersNames),
    );
    _addIfNotNull(
      fields,
      _validateServerAddress(data.ipAddress),
    );
    _addIfNotNull(
      fields,
      _validateDomain(data.domain),
    );
    _addIfNotNull(
      fields,
      _validateUsername(data.username),
    );
    _addIfNotNull(
      fields,
      _validatePassword(data.password),
    );
    _addIfNotNull(
      fields,
      _validateDnsServers(data.dnsServers),
    );

    return fields;
  }

  @override
  AddServerRequest toAddServerRequest({required ServerDetailsData data}) => (
    username: data.username,
    name: data.serverName,
    ipAddress: ValidationUtils.normalizeServerAddress(data.ipAddress),
    domain: data.domain.trim(),
    password: data.password,
    vpnProtocol: data.protocol,
    dnsServers: data.dnsServers.map((e) => e.trim()).toList(),
    routingProfileId: data.routingProfileId,
  );

  @override
  ServerDetailsData toServerDetailsData({required Server server}) => ServerDetailsData(
    serverName: server.name,
    ipAddress: server.ipAddress,
    domain: server.domain,
    username: server.username,
    password: server.password,
    protocol: server.vpnProtocol,
    routingProfileId: server.routingProfile.id,
    dnsServers: server.dnsServers.cast<String>(),
  );

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
}
