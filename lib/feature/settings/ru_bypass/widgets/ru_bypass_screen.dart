import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/widgets/ru_bypass_screen_view.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/widgets/scope/ru_bypass_scope.dart';

class RuBypassScreen extends StatefulWidget {
  const RuBypassScreen({super.key});

  @override
  State<RuBypassScreen> createState() => _RuBypassScreenState();
}

class _RuBypassScreenState extends State<RuBypassScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RuBypassScope.controllerOf(context, listen: false).fetchRuBypass();
    });
  }

  @override
  Widget build(BuildContext context) => const RuBypassScreenView();
}
