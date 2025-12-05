import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/error/model/enum/presentation_field_name.dart';
import 'package:vpn/common/localization/extensions/locale_enum_extension.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/common/utils/validation_utils.dart';
import 'package:vpn/data/model/routing_profile.dart';
import 'package:vpn/data/model/vpn_protocol.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';
import 'package:vpn/view/inputs/custom_text_field.dart';
import 'package:vpn/view/menu/custom_dropdown_menu.dart';

class ServerDetailsForm extends StatefulWidget {
  const ServerDetailsForm({super.key});

  @override
  State<ServerDetailsForm> createState() => _ServerDetailsFormState();
}

class _ServerDetailsFormState extends State<ServerDetailsForm> {
  @override
  Widget build(BuildContext context) => BlocBuilder<ServerDetailsBloc, ServerDetailsState>(
    buildWhen: (prev, current) => prev.action == current.action,
    builder: (context, state) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 32,
        children: [
          CustomTextField(
            value: state.data.serverName,
            label: context.ln.serverName,
            hint: context.ln.serverName,
            onChanged: (serverName) => _onDataChanged(
              context,
              serverName: serverName,
            ),
            error: ValidationUtils.getErrorString(
              context,
              state.fieldErrors,
              PresentationFieldName.serverName,
            ),
          ),
          CustomTextField(
            value: state.data.ipAddress,
            label: context.ln.enterIpAddressLabel,
            hint: context.ln.enterIpAddressHint,
            onChanged: (ipAddress) => _onDataChanged(
              context,
              ipAddress: ipAddress,
            ),
            error: ValidationUtils.getErrorString(
              context,
              state.fieldErrors,
              PresentationFieldName.ipAddress,
            ),
          ),
          CustomTextField(
            value: state.data.domain,
            label: context.ln.enterDomainLabel,
            hint: context.ln.enterDomainHint,
            onChanged: (domain) => _onDataChanged(
              context,
              domain: domain,
            ),
            error: ValidationUtils.getErrorString(
              context,
              state.fieldErrors,
              PresentationFieldName.domain,
            ),
          ),
          CustomTextField(
            value: state.data.username,
            label: context.ln.username,
            hint: context.ln.enterUsername,
            onChanged: (username) => _onDataChanged(
              context,
              username: username,
            ),
            error: ValidationUtils.getErrorString(
              context,
              state.fieldErrors,
              PresentationFieldName.userName,
            ),
          ),
          CustomTextField(
            value: state.data.password,
            label: context.ln.password,
            hint: context.ln.enterPassword,
            onChanged: (password) => _onDataChanged(
              context,
              password: password,
            ),
            error: ValidationUtils.getErrorString(
              context,
              state.fieldErrors,
              PresentationFieldName.password,
            ),
          ),
          CustomDropdownMenu<VpnProtocol>.expanded(
            value: state.data.protocol,
            values: VpnProtocol.values,
            toText: (value) => value.localized(context),
            labelText: context.ln.protocol,
            onChanged: (protocol) => _onDataChanged(
              context,
              protocol: protocol,
            ),
          ),
          CustomDropdownMenu<RoutingProfile>.expanded(
            value: state.selectedRoutingProfile,
            values: state.availableRoutingProfiles,
            toText: (value) => value.name,
            labelText: context.ln.routingProfile,
            onChanged: (profile) => _onDataChanged(
              context,
              routingProfileId: profile?.id,
            ),
          ),
          CustomTextField(
            value: state.data.dnsServers.join('\n'),
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
              state.fieldErrors,
              PresentationFieldName.dnsServers,
            ),
          ),
        ],
      ),
    ),
  );

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
  }) => context.read<ServerDetailsBloc>().add(
    ServerDetailsEvent.dataChanged(
      serverName: serverName,
      ipAddress: ipAddress,
      domain: domain,
      username: username,
      password: password,
      protocol: protocol,
      routingProfileId: routingProfileId,
      dnsServers: dnsServers,
    ),
  );
}
