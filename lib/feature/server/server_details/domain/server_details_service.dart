import 'package:vpn/common/error/model/enum/presentation_field_error_code.dart';
import 'package:vpn/common/error/model/enum/presentation_field_name.dart';
import 'package:vpn/common/error/model/presentation_field.dart';
import 'package:vpn/common/utils/validation_utils.dart';
import 'package:vpn/data/model/raw/add_server_request.dart';
import 'package:vpn/data/model/server.dart';
import 'package:vpn/feature/server/server_details/data/server_details_data.dart';

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
    if (serverName.isEmpty) {
      return _getRequiredField(fieldName);
    }
    if (otherServerNames.contains(serverName)) {
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

    final domainRegexp = RegExp(ValidationUtils.domainRawRegex);
    if (!domainRegexp.hasMatch(domain)) {
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
    final resultRegex = [
      ValidationUtils.dotRawRegex,
      ValidationUtils.dohRawRegex,
      ValidationUtils.quicRawRegex,
      ValidationUtils.h3RawRegex,
    ].map((e) => RegExp(e));

    for (final dnsServer in dnsServers) {
      if (!resultRegex.any((element) => element.hasMatch(dnsServer)) && !ValidationUtils.validateIpAddress(dnsServer)) {
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
