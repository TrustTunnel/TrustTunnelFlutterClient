import 'package:trusttunnel/common/router/app_route.dart';

abstract final class AppRoutes {
  static const AppRoute serverDetails = AppRoute('ServerDetailsPopUp');
  static const AppRoute servers = AppRoute('ServersScreen');
  static const AppRoute routing = AppRoute('RoutingScreen');
  static const AppRoute settings = AppRoute('SettingsScreen');
  static const AppRoute queryLog = AppRoute('QueryLogScreen');
  static const AppRoute unknown = AppRoute('UnknownScreen');

  static AppRoute byNavigationIndex(int selectedIndex) => switch (selectedIndex) {
    0 => servers,
    1 => routing,
    2 => settings,
    _ => unknown,
  };
}
