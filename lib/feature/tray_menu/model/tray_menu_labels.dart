import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';

/// Ready-to-display tray text prepared by the UI for its current locale.
final class TrayMenuLabels {
  final String connect;
  final String disconnect;
  final String connectTo;
  final String addServer;
  final String trayOpenApp;
  final String routing;
  final String connectionLog;
  final String logging;
  final String loggingLevel;
  final String loggingLevelBasic;
  final String loggingLevelDetailed;
  final String sensitiveData;
  final String sensitiveDataExcluded;
  final String sensitiveDataIncluded;
  final String deleteAppLogs;
  final String downloadAppLogs;
  final String trayQuitApp;
  final String otherServers;
  final Map<TrayMenuConnectionState, String> connectionTitles;
  final Map<TrayMenuConnectionState, String> statusTitles;

  const TrayMenuLabels({
    required this.connect,
    required this.disconnect,
    required this.connectTo,
    required this.addServer,
    required this.trayOpenApp,
    required this.routing,
    required this.connectionLog,
    required this.logging,
    required this.loggingLevel,
    required this.loggingLevelBasic,
    required this.loggingLevelDetailed,
    required this.sensitiveData,
    required this.sensitiveDataExcluded,
    required this.sensitiveDataIncluded,
    required this.deleteAppLogs,
    required this.downloadAppLogs,
    required this.trayQuitApp,
    required this.otherServers,
    required this.connectionTitles,
    required this.statusTitles,
  });
}
