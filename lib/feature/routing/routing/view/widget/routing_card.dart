import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/common_extensions.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/data/model/routing_profile.dart';
import 'package:vpn/feature/routing/routing/bloc/routing_bloc.dart';
import 'package:vpn/view/common/custom_radio_list_tile.dart';
import 'package:vpn/view/custom_svg_picture.dart';

class RoutingCard extends StatelessWidget {
  final RoutingProfile routingProfile;
  final RoutingState routingState;

  const RoutingCard({
    super.key,
    required this.routingProfile,
    required this.routingState,
  });

  bool get isDefaultProfile =>
      routingProfile == routingState.defaultRoutingProfile;
  bool get isOnlyProfile => routingState.allRoutingProfiles.length == 1;

  @override
  Widget build(BuildContext context) =>
      CustomRadioListTile<RoutingProfile?>.titleWidget(
        showRadioButton: !isOnlyProfile,
        enableTap: !isOnlyProfile,
        titleWidget: Text(
          isDefaultProfile ? context.ln.defaultProfile : routingProfile.name,
        ).bodyLarge(context),
        type: routingProfile,
        currentValue: routingState.selectedRoutingProfile,
        onChanged: (_) => _onSelectItem(context),
        trailing: PopupMenuButton(
          icon: const CustomSvgPicture(
            icon: AssetIcons.moreVert,
            size: 24,
          ),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              onTap: () => _onEditProfile(context),
              child: Row(
                children: [
                  const CustomSvgPicture(
                    icon: AssetIcons.modeEdit,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(context.ln.editProfile).bodyLarge(context),
                ],
              ),
            ),
            if (!isDefaultProfile)
              PopupMenuItem<String>(
                onTap: () => _onDeleteProfile(context),
                child: Row(
                  children: [
                    CustomSvgPicture(
                      icon: AssetIcons.delete,
                      size: 24,
                      color: context.colors.red1,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.ln.deleteProfile,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colors.red1,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  void _onSelectItem(BuildContext context) => context.read<RoutingBloc>().add(
        RoutingEvent.selectProfile(
          routingProfile: routingProfile,
        ),
      );

  void _onEditProfile(BuildContext context) {
    // TODO implement edit profile
  }

  void _onDeleteProfile(BuildContext context) {
    // TODO implement delete profile
  }
}
