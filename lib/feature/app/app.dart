import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/logging/observers/logging_navigator_observer.dart';
import 'package:trusttunnel/feature/app/widgets/app_system_ui_shell.dart';
import 'package:trusttunnel/feature/navigation/navigation_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final appSystemUiOverlayStyle = context.dependencyFactory.lightThemeData.appBarTheme.systemOverlayStyle;
      if (appSystemUiOverlayStyle != null) {
        SystemChrome.setSystemUIOverlayStyle(appSystemUiOverlayStyle);
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: context.dependencyFactory.lightThemeData,
    navigatorObservers: [
      LoggingNavigatorObserver(
        navigatorName: 'root',
      ),
    ],
    home: const AppSystemUIShell(
      child: NavigationScreen(),
    ),
    title: AppConstants.appName,
    locale: Localization.defaultLocale,
    localizationsDelegates: Localization.localizationDelegates,
    supportedLocales: Localization.supportedLocales,
  );
}
