import 'package:trusttunnel/common/router/app_route.dart';

abstract final class AppRoutes {
  static final AppRoute servers = AppRoute('ServersScreen');
  static final AppRoute routing = AppRoute('RoutingScreen');
  static final AppRoute settings = AppRoute('SettingsScreen');
  static final AppRoute serverDetails = AppRoute('ServerDetailsPopUp');
  static final AppRoute queryLog = AppRoute('QueryLogScreen');
  static final AppRoute unknown = AppRoute('UnknownScreen');

  static AppRoute byNavigationIndex(int selectedIndex) => switch (selectedIndex) {
    0 => servers,
    1 => routing,
    2 => settings,
    _ => unknown,
  };
}
