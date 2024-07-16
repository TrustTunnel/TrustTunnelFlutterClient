import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/server/server_details/server_details_screen.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/feature/server/servers/view/widget/servers_card.dart';
import 'package:vpn/view/buttons/floating_action_button_svg.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class ServersScreenView extends StatelessWidget {
  const ServersScreenView({
    super.key,
  });

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.ln.servers),
          ),
          body: BlocBuilder<ServersBloc, ServersState>(
            builder: (context, state) => ListView.separated(
              itemCount: state.serverList.length,
              itemBuilder: (_, index) {
                final item = state.serverList[index];

                return ServersCard(
                  server: item,
                );
              },
              separatorBuilder: (_, __) => const Divider(),
            ),
          ),
          floatingActionButton: FloatingActionButtonSvg.extended(
            icon: AssetIcons.add,
            onPressed: () => _pushServerDetailsScreen(context),
            label: context.ln.addServer,
          ),
        ),
      );

  void _pushServerDetailsScreen(BuildContext context) => context.push(
        const ServerDetailsScreen(),
      );
}
