import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/excluded_apps_screen_view.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/scope/excluded_apps_scope.dart';

class ExcludedAppsScreen extends StatefulWidget {
  const ExcludedAppsScreen({super.key});

  @override
  State<ExcludedAppsScreen> createState() => _ExcludedAppsScreenState();
}

class _ExcludedAppsScreenState extends State<ExcludedAppsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ExcludedAppsScope.controllerOf(context, listen: false).fetchExcludedApps();
    });
  }

  @override
  Widget build(BuildContext context) => const ExcludedAppsScreenView();
}
