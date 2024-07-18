import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
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
  Widget build(BuildContext context) {
    const separator32 = SizedBox(height: 32);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: BlocBuilder<ServerDetailsBloc, ServerDetailsState>(
            builder: (context, state) {
              return SliverList.list(
                children: [
                  CustomTextField(
                    value: state.data.serverName,
                    label: context.ln.serverName,
                    hint: context.ln.serverName,
                    onChanged: (serverName) => _onDataChanged(
                      context,
                      serverName: serverName,
                    ),
                  ),
                  separator32,
                  CustomTextField(
                    value: state.data.vpnServerIpAddress,
                    label: context.ln.serverDetailsVpnServerIpAddressLabel,
                    hint: context.ln.enterIpAddressFormatHint,
                    onChanged: (vpnServerIpAddress) => _onDataChanged(
                      context,
                      vpnServerIpAddress: vpnServerIpAddress,
                    ),
                  ),
                  separator32,
                  CustomTextField(
                    value: state.data.ipAddressDomain,
                    label: context.ln.serverDetailsIpAddressDomainLabel,
                    hint: context.ln.enterIpAddressFormatHint,
                    onChanged: (ipAddressDomain) => _onDataChanged(
                      context,
                      ipAddressDomain: ipAddressDomain,
                    ),
                  ),
                  separator32,
                  CustomTextField(
                    value: state.data.username,
                    label: context.ln.username,
                    hint: context.ln.enterUsername,
                    onChanged: (username) => _onDataChanged(
                      context,
                      username: username,
                    ),
                  ),
                  separator32,
                  CustomTextField(
                    value: state.data.password,
                    label: context.ln.password,
                    hint: context.ln.enterPassword,
                    onChanged: (password) => _onDataChanged(
                      context,
                      password: password,
                    ),
                  ),
                  separator32,
                  CustomDropdownMenu<VpnProtocol>.expanded(
                    value: state.data.protocol,
                    values: state.availableProtocols,
                    toText: (value) => value.toString(),
                    labelText: context.ln.protocol,
                    onChanged: (protocol) => _onDataChanged(
                      context,
                      protocol: protocol,
                    ),
                  ),
                  // TODO add routingProfile
                  // separator32,
                  // CustomDropdownMenu<String>.expanded(
                  //   value: _routingProfile ?? '',
                  //   values: _profileOptions,
                  //   toText: (value) => value,
                  //   labelText: context.ln.routingProfile,
                  //   onChanged: (profile) {},
                  //   // onChanged: (profile) => _onDataChanged(
                  //   //   context,
                  //   //   routingProfile: profile,
                  //   // ),
                  // ),
                  const SizedBox(
                    height: 27,
                  ),
                  Text(
                    context.ln.dnsServers,
                    style: context.textTheme.bodyLarge,
                  ),
                  const SizedBox(
                    height: 11,
                  ),
                  CustomTextField(
                    value: state.data.dnsServers.join('\n'),
                    hint: context.ln.enterDnsServerHint,
                    minLines: 4,
                    maxLines: 4,
                    onChanged: (dns) => _onDataChanged(
                      context,
                      dnsServers: dns.trim().split('\n'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _onDataChanged(
    BuildContext context, {
    String? serverName,
    String? vpnServerIpAddress,
    String? ipAddressDomain,
    String? username,
    String? password,
    VpnProtocol? protocol,
    List<String>? dnsServers,
  }) =>
      context.read<ServerDetailsBloc>().add(ServerDetailsEvent.dataChanged(
            serverName: serverName,
            vpnServerIpAddress: vpnServerIpAddress,
            ipAddressDomain: ipAddressDomain,
            username: username,
            password: password,
            protocol: protocol,
            dnsServers: dnsServers,
          ));
}
