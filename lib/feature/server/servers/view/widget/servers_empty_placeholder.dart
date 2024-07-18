import 'package:flutter/material.dart';
import 'package:vpn/common/assets/assets_vectors.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/server/server_details/view/server_details_screen.dart';
import 'package:vpn/view/default_page.dart';

class ServersEmptyPlaceholder extends StatelessWidget {
  const ServersEmptyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => DefaultPage.vector(
        title: context.ln.serversEmptyTitle,
        descriptionText: context.ln.serversEmptyDescription,
        vectorImage: AssetVectors.dns,
        imageSize: const Size.square(248),
        buttonText: context.ln.create,
        onButtonPressed: () => _pushServerDetailsScreen(context),
        alignment: Alignment.center,
      );

  void _pushServerDetailsScreen(BuildContext context) => context.push(
        const ServerDetailsScreen(),
      );
}
