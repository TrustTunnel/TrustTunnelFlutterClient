import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/routing_card.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_aspect.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_screen.dart';
import 'package:trusttunnel/widgets/buttons/custom_floating_action_button.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class RoutingScreenView extends StatefulWidget {
  const RoutingScreenView({super.key});

  @override
  State<RoutingScreenView> createState() => _RoutingScreenViewState();
}

class _RoutingScreenViewState extends State<RoutingScreenView> {
  late List<RoutingProfile> _routingProfiles;

  @override
  void initState() {
    super.initState();
    _routingProfiles = RoutingScope.controllerOf(context, listen: false).routingList;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routingProfiles = RoutingScope.controllerOf(
      context,
      aspect: RoutingScopeAspect.profiles,
    ).routingList;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.routing,
        ),
        body: ListView.builder(
          itemBuilder: (context, index) => Column(
            children: [
              RoutingCard(
                routingProfile: _routingProfiles[index],
              ),
              index == _routingProfiles.length - 1 ? const SizedBox(height: 80) : const Divider(),
            ],
          ),
          itemCount: _routingProfiles.length,
        ),
        floatingActionButton: CustomFloatingActionButton.extended(
          icon: AssetIcons.add,
          onPressed: () => _pushRoutingProfileDetailsScreen(context),
          label: context.ln.addProfile,
        ),
      ),
    ),
  );

  void _pushRoutingProfileDetailsScreen(BuildContext context) async {
    await context.push(
      const RoutingDetailsScreen(),
    );

    if (context.mounted) {
      RoutingScope.controllerOf(context, listen: false).fetchProfiles();
    }
  }
}
