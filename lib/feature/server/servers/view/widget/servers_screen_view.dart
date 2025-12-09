import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/server/server_details/view/server_details_popup.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/feature/server/servers/view/widget/servers_card.dart';
import 'package:vpn/feature/server/servers/view/widget/servers_empty_placeholder.dart';
import 'package:vpn/view/buttons/custom_floating_action_button.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class ServersScreenView extends StatelessWidget {
  const ServersScreenView({
    super.key,
  });

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.servers,
        ),
        body: BlocBuilder<ServersBloc, ServersState>(
          buildWhen: (previous, current) => previous.serverList != current.serverList,
          builder: (context, state) => state.loadingState == ServerLoadingState.idle
              ? state.serverList.isEmpty
                    ? const ServersEmptyPlaceholder()
                    : ListView.builder(
                        itemCount: state.serverList.length,
                        itemBuilder: (_, index) => Column(
                          children: [
                            ServersCard(
                              server: state.serverList[index],
                            ),
                            index == state.serverList.length - 1
                                ? const SizedBox(
                                    height: 80,
                                  )
                                : const Divider(),
                          ],
                        ),
                      )
              : const SizedBox.shrink(),
        ),
        floatingActionButton: BlocBuilder<ServersBloc, ServersState>(
          buildWhen: (previous, current) => previous.serverList.isEmpty != current.serverList.isEmpty,
          builder: (context, state) => state.serverList.isEmpty
              ? const SizedBox.shrink()
              : CustomFloatingActionButton.extended(
                  icon: AssetIcons.add,
                  onPressed: () => _pushServerDetailsScreen(context),
                  label: context.ln.addServer,
                ),
        ),
      ),
    ),
  );

  void _pushServerDetailsScreen(BuildContext context) async {
    final bloc = context.read<ServersBloc>();

    await context.push(
      const ServerDetailsPopUp(),
    );

    bloc.add(
      const ServersEvent.fetch(),
    );
  }
}
