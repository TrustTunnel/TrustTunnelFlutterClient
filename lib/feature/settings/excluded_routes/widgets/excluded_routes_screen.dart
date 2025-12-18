import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/excluded_routes_screen_view.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';

class ExcludedRoutesScreen extends StatefulWidget {
  const ExcludedRoutesScreen({super.key});

  @override
  State<ExcludedRoutesScreen> createState() => _ExcludedRoutesScreenState();
}

class _ExcludedRoutesScreenState extends State<ExcludedRoutesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ExcludedRoutesScope.controllerOf(context, listen: false).fetchExcludedRoutes();
    });
  }

  @override
  Widget build(BuildContext context) => const ExcludedRoutesScreenView();
}
