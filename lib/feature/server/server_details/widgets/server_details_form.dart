import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/localization/extensions/locale_enum_extension.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/utils/validation_utils.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/feature/server/server_details/model/server_details_data.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_aspect.dart';
import 'package:trusttunnel/widgets/inputs/custom_text_field.dart';
import 'package:trusttunnel/widgets/menu/custom_dropdown_menu.dart';

class ServerDetailsForm extends StatefulWidget {
  const ServerDetailsForm({super.key});

  @override
  State<ServerDetailsForm> createState() => _ServerDetailsFormState();
}

class _ServerDetailsFormState extends State<ServerDetailsForm> {
  late ServerDetailsData _formData;
  late List<PresentationField> _fieldErrors;
  late List<RoutingProfile> _routingProfiles;
  late RoutingProfile _pickedRoutingProfile;

  @override
  void initState() {
    super.initState();
    final controller = ServerDetailsScope.controllerOf(context, listen: false);
    _formData = controller.data;
    _fieldErrors = controller.fieldErrors;
    _routingProfiles = controller.routingProfiles;
    _pickedRoutingProfile = _getSelectedRoutingProfile(_routingProfiles, _formData.routingProfileId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dataSpecific = ServerDetailsScope.controllerOf(
      context,
      aspect: ServerDetailsScopeAspect.data,
    );

    _fieldErrors = ServerDetailsScope.controllerOf(
      context,
      aspect: ServerDetailsScopeAspect.fieldErrors,
    ).fieldErrors;

    _formData = dataSpecific.data;
    _routingProfiles = dataSpecific.routingProfiles;
    _pickedRoutingProfile = _getSelectedRoutingProfile(_routingProfiles, _formData.routingProfileId);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 32,
      children: [
        CustomTextField(
          value: _formData.serverName,
          label: context.ln.serverName,
          hint: context.ln.serverName,
          onChanged: (serverName) => _onDataChanged(
            context,
            serverName: serverName,
          ),
          error: ValidationUtils.getErrorString(
            context,
            _fieldErrors,
            PresentationFieldName.serverName,
          ),
        ),
        CustomTextField(
          value: _formData.ipAddress,
          label: context.ln.enterIpAddressLabel,
          hint: context.ln.enterIpAddressHint,
          onChanged: (ipAddress) => _onDataChanged(
            context,
            ipAddress: ipAddress,
          ),
          error: ValidationUtils.getErrorString(
            context,
            _fieldErrors,
            PresentationFieldName.ipAddress,
          ),
        ),
        CustomTextField(
          value: _formData.domain,
          label: context.ln.enterDomainLabel,
          hint: context.ln.enterDomainHint,
          onChanged: (domain) => _onDataChanged(
            context,
            domain: domain,
          ),
          error: ValidationUtils.getErrorString(
            context,
            _fieldErrors,
            PresentationFieldName.domain,
          ),
        ),
        CustomTextField(
          value: _formData.username,
          label: context.ln.username,
          hint: context.ln.enterUsername,
          onChanged: (username) => _onDataChanged(
            context,
            username: username,
          ),
          error: ValidationUtils.getErrorString(
            context,
            _fieldErrors,
            PresentationFieldName.userName,
          ),
        ),
        CustomTextField(
          value: _formData.password,
          label: context.ln.password,
          hint: context.ln.enterPassword,
          onChanged: (password) => _onDataChanged(
            context,
            password: password,
          ),
          error: ValidationUtils.getErrorString(
            context,
            _fieldErrors,
            PresentationFieldName.password,
          ),
        ),
        CustomDropdownMenu<VpnProtocol>.expanded(
          value: _formData.protocol,
          values: VpnProtocol.values,
          toText: (value) => value.localized(context),
          labelText: context.ln.protocol,
          onChanged: (protocol) => _onDataChanged(
            context,
            protocol: protocol,
          ),
        ),
        CustomDropdownMenu<RoutingProfile>.expanded(
          value: _pickedRoutingProfile,
          values: _routingProfiles,
          toText: (value) => value.name,
          labelText: context.ln.routingProfile,
          onChanged: (profile) => _onDataChanged(
            context,
            routingProfileId: profile?.id,
          ),
        ),
        CustomTextField(
          value: _formData.dnsServers.join('\n'),
          hint: context.ln.enterDnsServerHint,
          label: context.ln.enterDnsServerLabel,
          minLines: 1,
          maxLines: 4,
          onChanged: (dns) => _onDataChanged(
            context,
            dnsServers: dns.trim().split('\n'),
          ),
          error: ValidationUtils.getErrorString(
            context,
            _fieldErrors,
            PresentationFieldName.dnsServers,
          ),
        ),
      ],
    ),
  );

  RoutingProfile _getSelectedRoutingProfile(List<RoutingProfile> availableRoutingProfiles, int routingProfileId) =>
      availableRoutingProfiles.firstWhereOrNull((profile) => profile.id == routingProfileId) ??
      availableRoutingProfiles.firstWhere((profile) => profile.id == RoutingProfileUtils.defaultRoutingProfileId);

  void _onDataChanged(
    BuildContext context, {
    String? serverName,
    String? ipAddress,
    String? domain,
    String? username,
    String? password,
    VpnProtocol? protocol,
    int? routingProfileId,
    List<String>? dnsServers,
  }) =>
      ServerDetailsScope.controllerOf(
        context,
        listen: false,
      ).changeData(
        serverName: serverName,
        ipAddress: ipAddress,
        domain: domain,
        username: username,
        password: password,
        protocol: protocol,
        routingProfileId: routingProfileId,
        dnsServers: dnsServers,
      );
}
