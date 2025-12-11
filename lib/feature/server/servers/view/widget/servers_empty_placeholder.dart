import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/assets_images.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/server/server_details/view/server_details_popup.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/view/default_page.dart';

class ServersEmptyPlaceholder extends StatelessWidget {
  const ServersEmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => DefaultPage(
    title: context.ln.serversEmptyTitle,
    descriptionText: context.ln.serversEmptyDescription,
    imagePath: AssetImages.server,
    imageSize: const Size.square(248),
    buttonText: context.ln.create,
    onButtonPressed: () => _pushServerDetailsScreen(context),
    alignment: Alignment.center,
  );

  void _pushServerDetailsScreen(BuildContext context) => context
      .push(
        const ServerDetailsPopUp(),
      )
      .then(
        (_) => context.read<ServersBloc>().add(
          const ServersEvent.fetch(),
        ),
      );
}
