import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/data/model/routing_profile.dart';
import 'package:vpn/data/model/vpn_state.dart';
import 'package:vpn/feature/routing/routing/bloc/routing_bloc.dart';
import 'package:vpn/feature/routing/routing/common/routing_profile_utils.dart';
import 'package:vpn/feature/routing/routing/model/routing_profile_modification_result.dart';
import 'package:vpn/feature/routing/routing/view/widget/routing_delete_profile_dialog.dart';
import 'package:vpn/feature/routing/routing/view/widget/routing_edit_name_dialog.dart';
import 'package:vpn/feature/routing/routing_details/view/routing_details_screen.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/feature/vpn/widgets/vpn_scope.dart';
import 'package:vpn/view/common/custom_list_tile_separated.dart';
import 'package:vpn/view/custom_icon.dart';

class RoutingCard extends StatelessWidget {
  final RoutingProfile routingProfile;

  const RoutingCard({
    super.key,
    required this.routingProfile,
  });

  @override
  Widget build(BuildContext context) => CustomListTileSeparated(
    title: routingProfile.name,
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

  void _onEditName(BuildContext context) async {
    final bloc = context.read<RoutingBloc>();
    final result = await showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RoutingEditNameDialog(
          onSavePressed: (String value) => _editNameSubmit(bloc, value),
          currentRoutingName: routingProfile.name,
        ),
      ),
    );

    if (result == RoutingProfileModificationResult.saved) {
      bloc.add(
        const RoutingEvent.fetch(),
      );
    }
  }

  void _onDeleteProfile(BuildContext context) async {
    final serversBloc = context.read<ServersBloc>();
    final excludedRoutes = context.read<ExcludedRoutesBloc>().state.excludedRoutes;

    final bloc = context.read<RoutingBloc>();
    final result = await showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: RoutingDeleteProfileDialog(
          onDeletePressed: () => _deleteProfileSubmit(bloc),
          profileName: routingProfile.name,
        ),
      ),
    );

    if (!context.mounted || result != RoutingProfileModificationResult.deleted) {
      return;
    }

    final vpnScope = VpnScope.vpnControllerOf(context);

    final connected = vpnScope.state != VpnState.disconnected;
    final selectedServerId = serversBloc.state.selectedServerId;
    final pickedServer = serversBloc.state.serverList.firstWhereOrNull((s) => s.id == selectedServerId);
    final picked = pickedServer?.routingProfile.id == routingProfile.id;
    final defaultProfile = bloc.state.routingList.firstWhere(
      (s) => s.id == RoutingProfileUtils.defaultRoutingProfileId,
    );

    if (picked && connected) {
      vpnScope.start(
        server: pickedServer!,
        routingProfile: defaultProfile,
        excludedRoutes: excludedRoutes,
      );
    }
  }

  void _editNameSubmit(RoutingBloc bloc, String value) => bloc.add(
    RoutingEvent.editName(
      id: routingProfile.id,
      newName: value,
    ),
  );

  void _deleteProfileSubmit(RoutingBloc bloc) => bloc.add(
    RoutingEvent.deleteProfile(
      id: routingProfile.id,
    ),
  );

  void _pushDetailsScreen(BuildContext context) => context.push(
    RoutingDetailsScreen(
      routingId: routingProfile.id,
    ),
  );
}
