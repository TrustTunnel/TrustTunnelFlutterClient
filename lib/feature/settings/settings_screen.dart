import 'package:flutter/material.dart';
import 'package:vpn/view/custom_app_bar.dart';
import 'package:vpn/view/scaffold_wrapper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ScaffoldWrapper(
        child: Scaffold(
          appBar: CustomAppBar(
            title: 'Settings',
          ),
          body: Center(
            child: Text('Settings'),
          ),
        ),
      );
}
