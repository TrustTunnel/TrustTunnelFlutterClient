import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/routing_delete_profile_dialog.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/routing_edit_name_dialog.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_screen.dart';
import 'package:trusttunnel/widgets/common/custom_list_tile_separated.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

class RoutingCard extends StatelessWidget {
  final RoutingProfile routingProfile;

  const RoutingCard({
    super.key,
    required this.routingProfile,
  });

  @override
  Widget build(BuildContext context) => CustomListTileSeparated(
    title: routingProfile.data.name,
    onTileTap: () => _pushDetailsScreen(context),
    trailing: PopupMenuButton(
      icon: const CustomIcon(
        icon: AssetIcons.moreVert,
        size: 24,
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          onTap: () => _onEditName(context),
          child: Row(
            children: [
              const CustomIcon(
                icon: AssetIcons.modeEdit,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                context.ln.editProfile,
                style: context.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        if (!RoutingProfileUtils.isDefaultRoutingProfile(profile: routingProfile))
          PopupMenuItem<String>(
            onTap: () => _onDeleteProfile(context),
            child: Row(
              children: [
                CustomIcon.medium(
                  icon: AssetIcons.delete,
                  color: context.colors.error,
                ),
                const SizedBox(width: 12),
                Text(
                  context.ln.deleteProfile,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  void _onEditName(BuildContext context) {
    final controller = RoutingScope.controllerOf(context, listen: false);
    controller.pickProfileToChangeName();

    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    showDialog(
      context: context,
      builder: (innerContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
        child: RoutingScopeValue.fromContext(
          context: context,
          child: RoutingEditNameDialog(
            currentRoutingName: routingProfile.data.name,
            id: routingProfile.id,
          ),
        ),
      ),
    );
  }

  void _onDeleteProfile(BuildContext context) async {
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    await showDialog(
      context: context,
      builder: (innerContext) => ScaffoldMessengerProvider(
        value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
        child: RoutingScopeValue.fromContext(
          context: context,
          child: RoutingDeleteProfileDialog(
            profileName: routingProfile.data.name,
            profileId: routingProfile.id,
          ),
        ),
      ),
    );
  }

  void _pushDetailsScreen(BuildContext context) async {
    await context.push(
      RoutingDetailsScreen(
        routingId: routingProfile.id,
      ),
    );

    if (context.mounted) {
      RoutingScope.controllerOf(context, listen: false).fetchProfiles();
    }
  }
}
