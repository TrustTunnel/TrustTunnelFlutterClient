import 'package:flutter/material.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/app_logging_body.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class AppLoggingScreen extends StatelessWidget {
  const AppLoggingScreen({super.key});

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: ScaffoldMessenger(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.appLogging,
          centerTitle: true,
          leadingIconType: AppBarLeadingIconType.back,
        ),
        body: const AppLoggingBody(),
      ),
    ),
  );
}
