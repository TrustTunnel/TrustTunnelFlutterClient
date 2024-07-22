import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/localization/localization.dart';
import 'package:vpn/feature/routing/routing/bloc/routing_bloc.dart';
import 'package:vpn/feature/routing/routing/view/widget/routing_card.dart';
import 'package:vpn/view/buttons/floating_action_button_svg.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class RoutingScreenView extends StatelessWidget {
  const RoutingScreenView({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
        child: Scaffold(
          appBar: CustomAppBar(
            title: context.ln.routing,
          ),
          body: BlocBuilder<RoutingBloc, RoutingState>(
            builder: (context, state) => ListView.separated(
              itemBuilder: (context, index) => RoutingCard(
                routingProfile: state.allRoutingProfiles[index],
                routingState: state,
              ),
              separatorBuilder: (_, __) => const Divider(),
              itemCount: state.allRoutingProfiles.length,
            ),
          ),
          floatingActionButton: FloatingActionButtonSvg.extended(
            icon: AssetIcons.add,
            onPressed: () => _pushRoutingProfileDetailsScreen(context),
            label: context.ln.addProfile,
          ),
        ),
      );

  _pushRoutingProfileDetailsScreen(BuildContext context) {
    // TODO implement push routing profile details screen
  }
}
