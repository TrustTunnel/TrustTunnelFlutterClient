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
    final List<PresentationField> fields = [];
    final serverNameValidationResult = _validateServerName(
      data.serverName,
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

    return fields;
  }

  @override
  AddServerRequest toAddServerRequest({required ServerDetailsData data}) => (
    username: data.username,
    name: data.serverName,
    ipAddress: data.ipAddress,
    domain: data.domain,
    password: data.password,
    vpnProtocol: data.protocol,
    dnsServers: data.dnsServers,
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
        dnsServer = dnsServer.replaceFirst(allowableRegex, '');
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
}
