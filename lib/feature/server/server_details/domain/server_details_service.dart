import 'package:vpn/common/error/model/enum/presentation_field_error_code.dart';
import 'package:vpn/common/error/model/enum/presentation_field_name.dart';
import 'package:vpn/common/error/model/presentation_field.dart';
import 'package:vpn/data/repository/server_repository.dart';
import 'package:vpn/feature/server/server_details/data/server_details_data.dart';
import 'package:vpn_plugin/platform_api.g.dart';

abstract class ServerDetailsService {
  List<PresentationField> validateData({required ServerDetailsData data});

  AddServerRequest toAddServerRequest({required ServerDetailsData data});

  UpdateServerRequest toUpdateServerRequest({
    required int id,
    required ServerDetailsData data,
  });

  ServerDetailsData toServerDetailsData({required Server server});
}

class ServerDetailsServiceImpl implements ServerDetailsService {
  final ServerRepository _serverRepository;

  ServerDetailsServiceImpl({
    required ServerRepository serverRepository,
  }) : _serverRepository = serverRepository;

  @override
  List<PresentationField> validateData({required ServerDetailsData data}) {
    final List<PresentationField> fields = [];
    if (data.serverName.isEmpty) {
      fields.add(_getRequiredField(PresentationFieldName.serverName));
    }
    if (data.ipAddress.isEmpty) {
      fields.add(_getRequiredField(PresentationFieldName.ipAddress));
    }
    if (data.domain.isEmpty) {
      fields.add(_getRequiredField(PresentationFieldName.domain));
    }
    if (data.username.isEmpty) {
      fields.add(_getRequiredField(PresentationFieldName.userName));
    }
    if (data.password.isEmpty) {
      fields.add(_getRequiredField(PresentationFieldName.password));
    }
    if (data.dnsServers.isEmpty) {
      fields.add(_getRequiredField(PresentationFieldName.dnsServers));
    }

    return fields;
  }

  @override
  AddServerRequest toAddServerRequest({required ServerDetailsData data}) => AddServerRequest(
        name: data.serverName,
        ipAddress: data.ipAddress,
        domain: data.domain,
        login: data.username,
        password: data.password,
        vpnProtocol: data.protocol,
        dnsServers: data.dnsServers,
        // TODO uncomment when routingProfile will be added to ServerDetailsData
        //routingProfileId: data.routingProfile!.id,
        routingProfileId: 0,
      );

  @override
  UpdateServerRequest toUpdateServerRequest({
    required int id,
    required ServerDetailsData data,
  }) =>
      UpdateServerRequest(
        id: id,
        name: data.serverName,
        ipAddress: data.ipAddress,
        domain: data.domain,
        login: data.username,
        password: data.password,
        vpnProtocol: data.protocol,
        dnsServers: data.dnsServers,
        // TODO uncomment when routingProfile will be added to ServerDetailsData
        //routingProfileId: data.routingProfile!.id,
        routingProfileId: 0,
      );

  @override
  ServerDetailsData toServerDetailsData({required Server server}) => ServerDetailsData(
        serverName: server.name,
        ipAddress: server.ipAddress,
        domain: server.domain,
        username: server.login,
        password: server.password,
        protocol: server.vpnProtocol,
        // TODO add routingProfile from serverRepository by id
        routingProfile: null,
        dnsServers: server.dnsServers.cast<String>(),
      );

  PresentationField _getRequiredField(PresentationFieldName fieldName) => PresentationField(
        code: PresentationFieldErrorCode.fieldRequired,
        fieldName: fieldName,
      );
}
