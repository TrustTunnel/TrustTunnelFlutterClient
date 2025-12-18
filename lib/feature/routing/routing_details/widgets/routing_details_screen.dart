import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/routing_details_screen_view.dart';
import 'package:trusttunnel/feature/routing/routing_details/widgets/scope/routing_details_scope.dart';

class RoutingDetailsScreen extends StatelessWidget {
  final int? routingId;
  const RoutingDetailsScreen({super.key, this.routingId});

  @override
  Widget build(BuildContext context) => RoutingDetailsScope(
    profileId: routingId,
    child: const RoutingDetailsScreenView(),
  );
}
