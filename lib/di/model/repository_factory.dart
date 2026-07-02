import 'package:trusttunnel/data/repository/auto_connect_on_launch_settings_repository.dart';
import 'package:trusttunnel/data/repository/deep_link_repository.dart';
import 'package:trusttunnel/data/repository/export_logs_repository.dart';
import 'package:trusttunnel/data/repository/launch_at_login_repository.dart';
import 'package:trusttunnel/data/repository/logging_settings_repository.dart';
import 'package:trusttunnel/data/repository/open_main_window_on_login_repository.dart';
import 'package:trusttunnel/data/repository/routing_repository.dart';
import 'package:trusttunnel/data/repository/server_repository.dart';
import 'package:trusttunnel/data/repository/settings_repository.dart';
import 'package:trusttunnel/data/repository/vpn_repository.dart';
import 'package:trusttunnel/di/model/dependency_factory.dart';

abstract class RepositoryFactory {
  ServerRepository get serverRepository;

  SettingsRepository get settingsRepository;

  RoutingRepository get routingRepository;

  VpnRepository get vpnRepository;

  DeepLinkRepository get deepLinkRepository;

  LoggingSettingsRepository get loggingSettingsRepository;

  ExportLogsRepository get exportLogsRepository;

  LaunchAtLoginRepository get launchAtLoginRepository;

  OpenMainWindowOnLoginRepository get openMainWindowOnLoginRepository;

  AutoConnectOnLaunchSettingsRepository get autoConnectOnLaunchSettingsRepository;
}

class RepositoryFactoryImpl implements RepositoryFactory {
  final DependencyFactory _dependencyFactory;

  RepositoryFactoryImpl({
    required DependencyFactory dependencyFactory,
  }) : _dependencyFactory = dependencyFactory;

  ServerRepository? _serverRepository;

  SettingsRepository? _settingsRepository;

  RoutingRepository? _routingRepository;

  VpnRepository? _vpnRepository;

  DeepLinkRepository? _deepLinkRepository;

  LoggingSettingsRepository? _loggingSettingsRepository;

  ExportLogsRepository? _exportLogsRepository;

  LaunchAtLoginRepository? _launchAtLoginRepository;

  OpenMainWindowOnLoginRepository? _openMainWindowOnLoginRepository;

  AutoConnectOnLaunchSettingsRepository? _autoConnectOnLaunchSettingsRepository;

  @override
  ServerRepository get serverRepository => _serverRepository ??= ServerRepositoryImpl(
    serverDataSource: _dependencyFactory.serverDataSource,
    certificateDataSource: _dependencyFactory.certificateDataSource,
  );

  @override
  SettingsRepository get settingsRepository => _settingsRepository ??= SettingsRepositoryImpl(
    settingsDataSource: _dependencyFactory.settingsDataSource,
  );

  @override
  RoutingRepository get routingRepository => _routingRepository ??= RoutingRepositoryImpl(
    routingDataSource: _dependencyFactory.routingDataSource,
  );

  @override
  VpnRepository get vpnRepository => _vpnRepository ??= VpnRepositoryImpl(
    vpnDataSource: _dependencyFactory.vpnDataSource,
  );

  @override
  DeepLinkRepository get deepLinkRepository => _deepLinkRepository ??= DeepLinkRepositoryImpl(
    serverDataSource: _dependencyFactory.serverDataSource,
  );

  @override
  LoggingSettingsRepository get loggingSettingsRepository =>
      _loggingSettingsRepository ??= LoggingSettingsRepositoryImpl(
        dataSource: _dependencyFactory.loggingSettingsDataSource,
      );

  @override
  ExportLogsRepository get exportLogsRepository => _exportLogsRepository ??= ExportLogsRepositoryImpl(
    localSource: _dependencyFactory.exportLogsLocalSource,
  );

  @override
  LaunchAtLoginRepository get launchAtLoginRepository => _launchAtLoginRepository ??= LaunchAtLoginRepositoryImpl(
    dataSource: _dependencyFactory.launchAtLoginDataSource,
  );

  @override
  OpenMainWindowOnLoginRepository get openMainWindowOnLoginRepository =>
      _openMainWindowOnLoginRepository ??= OpenMainWindowOnLoginRepositoryImpl(
        dataSource: _dependencyFactory.openMainWindowOnLoginDataSource,
      );

  @override
  AutoConnectOnLaunchSettingsRepository get autoConnectOnLaunchSettingsRepository =>
      _autoConnectOnLaunchSettingsRepository ??= AutoConnectOnLaunchSettingsRepositoryImpl(
        dataSource: _dependencyFactory.autoConnectOnLaunchSettingsDataSource,
      );
}
