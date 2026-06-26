import 'package:flutter/material.dart' hide Router;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/menu_bar/widgets/tray_menu_scope.dart';
import 'package:trusttunnel/feature/navigation/navigation_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: context.dependencyFactory.lightThemeData,
    home: Builder(
      builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: context.colors.background,
          statusBarBrightness: context.theme.brightness,
        ),
        child: const TrayMenuScope(
          child: NavigationScreen(),
        ),
      ),
    ),
    title: 'TrustTunnel',
    locale: Localization.defaultLocale,
    localizationsDelegates: Localization.localizationDelegates,
    supportedLocales: Localization.supportedLocales,
  );
}
