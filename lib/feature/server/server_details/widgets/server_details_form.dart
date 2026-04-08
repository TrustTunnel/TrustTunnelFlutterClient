import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/localization/extensions/locale_enum_extension.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/common/utils/validation_utils.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/scope/server_details_scope_aspect.dart';
import 'package:trusttunnel/widgets/buttons/custom_icon_button.dart';
import 'package:trusttunnel/widgets/inputs/custom_text_field.dart';
import 'package:trusttunnel/widgets/menu/custom_dropdown_menu.dart';

class ServerDetailsForm extends StatefulWidget {
  const ServerDetailsForm({super.key});

  @override
  State<ServerDetailsForm> createState() => _ServerDetailsFormState();
}

class _ServerDetailsFormState extends State<ServerDetailsForm> {
  late ServerData _formData;
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
  Widget build(BuildContext context) {
    final clientRandomError = [
      ValidationUtils.getErrorString(
        context,
        _fieldErrors,
        PresentationFieldName.clientRandom,
      ),
      ValidationUtils.getErrorString(
        context,
        _fieldErrors,
        PresentationFieldName.clientRandomMask,
      ),
      ValidationUtils.getErrorString(
        context,
        _fieldErrors,
        PresentationFieldName.clientRandomValue,
      ),
    ].whereType<String>().firstOrNull;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 32,
            children: [
              CustomTextField(
                value: _formData.name,
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
                helper: context.ln.enterIpAddressHelper,
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
                value: _formData.customSni,
                label: context.ln.customSniLabel,
                hint: context.ln.customSniHint,
                onChanged: (domain) => _onDataChanged(
                  context,
                  customSni: ValueData(domain.trim().isEmpty ? null : domain),
                ),
                error: ValidationUtils.getErrorString(
                  context,
                  _fieldErrors,
                  PresentationFieldName.sni,
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
                value: _formData.vpnProtocol,
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
                toText: (value) => value.data.name,
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
                helper: context.ln.enterDnsServerHelper,
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
          const SizedBox(
            height: 12,
          ),
          CustomTextField(
            value: _formData.tlsPrefix,
            hint: context.ln.clientRandomHint,
            label: context.ln.clientRandomLabel,
            helper: context.ln.clientRandomHelper,
            counter: const SizedBox.shrink(),
            maxLength: 64,
            onChanged: (tls) => _onDataChanged(
              context,
              clientRandom: ValueData(
                tls.isEmpty ? null : tls,
              ),
            ),
            error: clientRandomError,
          ),
          const SizedBox(
            height: 16,
          ),
          CustomTextField.customSuffixIcon(
            value: _formData.certificate?.name,
            label: context.ln.pemLabel,
            readOnly: true,
            suffixIcon: _formData.certificate != null
                ? CustomIconButton(
                    icon: AssetIcons.close,
                    onPressed: () => _onClearPemCertificatePressed(
                      context,
                    ),
                  )
                : CustomIconButton(
                    icon: AssetIcons.attach,
                    onPressed: () => _onSelectPemCertificatePressed(
                      context,
                    ),
                  ),
            error: ValidationUtils.getErrorString(
              context,
              _fieldErrors,
              PresentationFieldName.certificate,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          CheckboxListTile(
            value: _formData.ipv6,
            title: Text(
              context.ln.ipv6Label,
            ),
            contentPadding: const EdgeInsets.all(4),
            onChanged: (value) => _onDataChanged(
              context,
              enableIpv6: value,
            ),
          ),
        ],
      ),
    );
  }

  RoutingProfile _getSelectedRoutingProfile(List<RoutingProfile> availableRoutingProfiles, String routingProfileId) =>
      availableRoutingProfiles.firstWhereOrNull((profile) => profile.id == routingProfileId) ??
      availableRoutingProfiles.firstWhere((profile) => profile.id == RoutingProfileUtils.defaultRoutingProfileId);

  void _onSelectPemCertificatePressed(
    BuildContext context,
  ) => ServerDetailsScope.controllerOf(context, listen: false).pickPemCertificate();

  void _onClearPemCertificatePressed(
    BuildContext context,
  ) => ServerDetailsScope.controllerOf(context, listen: false).clearPemCertificate();

  void _onDataChanged(
    BuildContext context, {
    String? serverName,
    String? ipAddress,
    String? domain,
    String? username,
    String? password,
    ValueData<String>? clientRandom,
    bool? enableIpv6,
    VpnProtocol? protocol,
    String? routingProfileId,
    List<String>? dnsServers,
    ValueData<String>? customSni,
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
        clientRandom: clientRandom,
        enableIpv6: enableIpv6,
        routingProfileId: routingProfileId,
        dnsServers: dnsServers,
        customSni: customSni,
      );
}
