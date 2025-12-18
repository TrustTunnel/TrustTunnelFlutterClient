import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/routing_screen_view.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';

class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key});

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RoutingScope.controllerOf(context, listen: false).fetchProfiles();
    });
  }

  @override
  Widget build(BuildContext context) => const RoutingScreenView();
}
