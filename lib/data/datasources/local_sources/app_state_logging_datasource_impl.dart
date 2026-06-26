import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/model/app_state_snapshot.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/database/connection.dart';
import 'package:trusttunnel/data/datasources/app_state_logging_datasource.dart';
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';
import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/datasources/settings_datasource.dart';
import 'package:trusttunnel/data/datasources/vpn_datasource.dart';

final class AppStateLoggingDataSourceImpl implements AppStateLoggingDataSource {
  final db.AppDatabase _database;
  final ServerDataSource _serverDataSource;
  final RoutingDataSource _routingDataSource;
  final SettingsDataSource _settingsDataSource;
  final VpnDataSource _vpnDataSource;
  final LoggingSettingsDataSource _loggingSettingsDataSource;

  const AppStateLoggingDataSourceImpl({
    required db.AppDatabase database,
    required ServerDataSource serverDataSource,
    required RoutingDataSource routingDataSource,
    required SettingsDataSource settingsDataSource,
    required VpnDataSource vpnDataSource,
    required LoggingSettingsDataSource loggingSettingsDataSource,
  }) : _database = database,
       _serverDataSource = serverDataSource,
       _routingDataSource = routingDataSource,
       _settingsDataSource = settingsDataSource,
       _vpnDataSource = vpnDataSource,
       _loggingSettingsDataSource = loggingSettingsDataSource;

  @override
  Future<AppStateSnapshot> collectSnapshot() async {
    final packageInfoFuture = PackageInfo.fromPlatform();
    final serversFuture = _serverDataSource.getAllServers();
    final routingProfilesFuture = _routingDataSource.getAllProfiles();
    final excludedRoutesFuture = _settingsDataSource.getExcludedRoutes();
    final queryLogsFuture = _database.select(_database.vpnRequests).get();
    final vpnStatusFuture = _collectVpnStatus();
    final databaseSnapshotFuture = _collectDatabaseSnapshot();

    final packageInfo = await packageInfoFuture;
    final servers = await serversFuture;
    final routingProfiles = await routingProfilesFuture;
    final excludedRoutes = await excludedRoutesFuture;
    final queryLogs = await queryLogsFuture;
    final vpnStatus = await vpnStatusFuture;
    final databaseSnapshot = await databaseSnapshotFuture;
    final securityType = await _loggingSettingsDataSource.getSecurityType();
    final level = await _loggingSettingsDataSource.getLoggingLevel();
    final includeSensitiveData = securityType == LoggingSecurityType.full;

    return AppStateSnapshot(
      app: AppMetadataSnapshot(
        name: packageInfo.appName,
        version: packageInfo.version,
        build: packageInfo.buildNumber,
        platform: defaultTargetPlatform.name,
      ),
      vpn: vpnStatus,
      database: databaseSnapshot,
      logging: LoggingConfigurationSnapshot(
        securityType: securityType.value,
        level: level.value,
      ),
      servers: ServersSnapshot.fromServers(
        servers,
        selectedServer: servers.selectedServer,
        includeSensitiveData: includeSensitiveData,
      ),
      routingProfiles: RoutingProfilesSnapshot.fromProfiles(
        routingProfiles,
        includeRules: includeSensitiveData,
      ),
      excludedRoutes: ExcludedRoutesSnapshot.fromRoutes(
        excludedRoutes,
        includeItems: includeSensitiveData,
      ),
      queryLog: QueryLogSnapshot.fromRows(
        queryLogs,
        includeItems: includeSensitiveData,
      ),
    );
  }

  Future<VpnStatusSnapshot> _collectVpnStatus() async {
    try {
      final state = await _vpnDataSource.requestState();

      return VpnStatusSnapshot(state: state.name);
    } on Object {
      return const VpnStatusSnapshot(state: 'unavailable');
    }
  }

  Future<DatabaseSnapshot> _collectDatabaseSnapshot() async {
    try {
      final file = await databaseFile;
      final fileSize = await file.length();

      return DatabaseSnapshot(
        schemaVersion: _database.schemaVersion,
        fileSize: fileSize,
      );
    } on Object {
      return DatabaseSnapshot(
        schemaVersion: _database.schemaVersion,
        fileSize: 'unavailable',
      );
    }
  }
}
