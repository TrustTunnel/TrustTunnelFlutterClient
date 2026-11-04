import 'dart:io';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/constants/app_update_constants.dart';
import 'package:trusttunnel/common/network/models/http_client_configuration.dart';
import 'package:trusttunnel/common/network/network_client.dart';
import 'package:trusttunnel/common/theme/light_theme.dart';
import 'package:trusttunnel/common/utils/certificate_encoders.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/app_state_logging_datasource.dart';
import 'package:trusttunnel/data/datasources/app_update_installation_datasource.dart';
import 'package:trusttunnel/data/datasources/app_updates_local_datasource.dart';
import 'package:trusttunnel/data/datasources/auto_connect_on_launch_settings_datasource.dart';
import 'package:trusttunnel/data/datasources/certificate_datasource.dart';
import 'package:trusttunnel/data/datasources/launch_at_login_datasource.dart';
import 'package:trusttunnel/data/datasources/local_sources/app_state_logging_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/app_updates_local_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/auto_connect_on_launch_settings_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/certificate_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/logging_settings_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/logs_local_source_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/routing_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/server_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/settings_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_local_source.dart';
import 'package:trusttunnel/data/datasources/native_sources/launch_at_login_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/native_sources/open_main_window_on_login_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/native_sources/vpn_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/native_sources/windows_app_update_installation_datasource.dart';
import 'package:trusttunnel/data/datasources/open_main_window_on_login_datasource.dart';
import 'package:trusttunnel/data/datasources/releases_datasource.dart';
import 'package:trusttunnel/data/datasources/remote_sources/releases_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/datasources/settings_datasource.dart';
import 'package:trusttunnel/data/datasources/vpn_datasource.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/app/controller/linux_app_window_controller.dart';
import 'package:trusttunnel/feature/app/controller/macos_app_window_controller.dart';
import 'package:trusttunnel/feature/app/controller/windows_app_window_controller.dart';
import 'package:vpn_plugin/deep_link_manager.dart';
import 'package:vpn_plugin/domain/configuration_codec.dart';
import 'package:vpn_plugin/platform_api.g.dart' show IDeepLink;
import 'package:vpn_plugin/vpn_plugin.dart';

abstract class DependencyFactory {
  abstract final SharedPreferences sharedPreferences;

  abstract final FileLogAppender fileLogAppender;

  abstract final FileLogStorage logStorage;

  AppUpdatesLocalDataSource get appUpdatesLocalDataSource;

  AppUpdateInstallationDataSource get appUpdateInstallationDataSource;

  ReleasesDataSource get releasesDataSource;

  NetworkClient get releasesHttpClient;

  NetworkClient get fileDownloadClient;

  ThemeData get lightThemeData;

  VpnPlugin get vpnPlugin;

  DeepLinkManager get deepLinkManager;

  SettingsDataSource get settingsDataSource;

  ServerDataSource get serverDataSource;

  RoutingDataSource get routingDataSource;

  VpnDataSource get vpnDataSource;

  CertificateDataSource get certificateDataSource;

  LoggingSettingsDataSource get loggingSettingsDataSource;

  AppStateLoggingDataSource get appStateLoggingDataSource;

  LogsLocalSource get exportLogsLocalSource;

  LaunchAtLoginDataSource get launchAtLoginDataSource;

  OpenMainWindowOnLoginDataSource get openMainWindowOnLoginDataSource;

  AutoConnectOnLaunchSettingsDataSource get autoConnectOnLaunchSettingsDataSource;

  /// Returns the cached native window controller on macOS and Windows.
  /// Throws on platforms without native window control.
  AppWindowController get appWindowController;

  db.AppDatabase get database;

  Future<void> close();
}

class DependencyFactoryImpl implements DependencyFactory {
  @override
  final SharedPreferences sharedPreferences;

  @override
  final FileLogAppender fileLogAppender;

  @override
  final FileLogStorage logStorage;

  DependencyFactoryImpl({
    required this.sharedPreferences,
    required this.fileLogAppender,
    required this.logStorage,
  });

  final AppUpdatesLocalDataSource _appUpdatesLocalDataSource = AppUpdatesLocalDataSourceImpl(
    repositoryName: AppUpdateConstants.repositoryName,
  );

  AppUpdateInstallationDataSource? _appUpdateInstallationDataSource;

  ReleasesDataSource? _releasesDataSource;

  NetworkClient? _releasesHttpClient;

  NetworkClient? _fileDownloadClient;

  ThemeData? _lightThemeData;

  VpnPlugin? _vpnPlugin;

  DeepLinkManager? _deepLinkManager;

  SettingsDataSource? _settingsDataSource;

  ServerDataSource? _serverDataSource;

  RoutingDataSource? _routingDataSource;

  VpnDataSource? _vpnDataSource;

  CertificateDataSource? _certificateDataSource;

  LoggingSettingsDataSource? _loggingSettingsDataSource;

  AppStateLoggingDataSource? _appStateLoggingDataSource;

  LogsLocalSource? _exportLogsLocalSource;

  LaunchAtLoginDataSource? _launchAtLoginDataSource;

  OpenMainWindowOnLoginDataSource? _openMainWindowOnLoginDataSource;

  AutoConnectOnLaunchSettingsDataSource? _autoConnectOnLaunchSettingsDataSource;

  AppWindowController? _appWindowController;

  db.AppDatabase? _database;

  @override
  AppUpdatesLocalDataSource get appUpdatesLocalDataSource => _appUpdatesLocalDataSource;

  @override
  AppUpdateInstallationDataSource get appUpdateInstallationDataSource =>
      _appUpdateInstallationDataSource ??= WindowsAppUpdateInstallationDataSource();

  @override
  ReleasesDataSource get releasesDataSource => _releasesDataSource ??= ReleasesDataSourceImpl(
    releasesClient: releasesHttpClient,
    downloadsClient: fileDownloadClient,
    baseUrl: AppUpdateConstants.releasesUrl,
    repositoryName: AppUpdateConstants.repositoryName,
  );

  @override
  NetworkClient get releasesHttpClient => _releasesHttpClient ??= NetworkClient(
    configuration: HttpClientConfiguration(
      timeout: AppUpdateConstants.requestTimeout,
      userAgent: AppConstants.appName,
      headers: const {
        HttpHeaders.acceptHeader: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );

  @override
  NetworkClient get fileDownloadClient => _fileDownloadClient ??= NetworkClient(
    configuration: HttpClientConfiguration(
      timeout: AppUpdateConstants.requestTimeout,
      userAgent: AppConstants.appName,
      headers: const {HttpHeaders.acceptHeader: 'application/octet-stream'},
    ),
  );

  @override
  ThemeData get lightThemeData => _lightThemeData ??= LightTheme().data;

  @override
  VpnPlugin get vpnPlugin => _vpnPlugin ??= VpnPluginImpl();

  @override
  DeepLinkManager get deepLinkManager => _deepLinkManager ??= DeepLinkManagerImpl(
    deepLinkParser: IDeepLink(),
    codec: const ConfigurationCodec(),
    endpointEncoder: const EndpointEncoder(),
  );

  @override
  SettingsDataSource get settingsDataSource => _settingsDataSource ??= SettingsDataSourceImpl(database: database);

  @override
  ServerDataSource get serverDataSource => _serverDataSource ??= ServerDataSourceImpl(
    database: database,
    deepLinkManager: deepLinkManager,
  );

  @override
  RoutingDataSource get routingDataSource => _routingDataSource ??= RoutingDataSourceImpl(
    database: database,
  );

  @override
  VpnDataSource get vpnDataSource => _vpnDataSource ??= VpnDataSourceImpl(
    vpnPlugin: vpnPlugin,
  );

  @override
  CertificateDataSource get certificateDataSource => _certificateDataSource ??= CertificateDataSourceImpl(
    filePicker: FilePicker.platform,
    decoder: const RawCertificateDecoder(),
  );

  @override
  LoggingSettingsDataSource get loggingSettingsDataSource =>
      _loggingSettingsDataSource ??= LoggingSettingsDataSourceImpl(
        preferences: sharedPreferences,
      );

  @override
  AppStateLoggingDataSource get appStateLoggingDataSource =>
      _appStateLoggingDataSource ??= AppStateLoggingDataSourceImpl(
        database: database,
        serverDataSource: serverDataSource,
        routingDataSource: routingDataSource,
        settingsDataSource: settingsDataSource,
        vpnDataSource: vpnDataSource,
        loggingSettingsDataSource: loggingSettingsDataSource,
      );

  @override
  LogsLocalSource get exportLogsLocalSource => _exportLogsLocalSource ??= LogsLocalSourceImpl(
    logAppender: fileLogAppender,
    appStateLoggingDataSource: appStateLoggingDataSource,
    filePicker: FilePicker.platform,
    vpnPlugin: vpnPlugin,
    sharedPreferences: sharedPreferences,
  );

  @override
  LaunchAtLoginDataSource get launchAtLoginDataSource => _launchAtLoginDataSource ??= LaunchAtLoginDataSourceImpl();

  @override
  OpenMainWindowOnLoginDataSource get openMainWindowOnLoginDataSource =>
      _openMainWindowOnLoginDataSource ??= OpenMainWindowOnLoginDataSourceImpl();

  @override
  AutoConnectOnLaunchSettingsDataSource get autoConnectOnLaunchSettingsDataSource =>
      _autoConnectOnLaunchSettingsDataSource ??= AutoConnectOnLaunchSettingsDataSourceImpl(
        preferences: sharedPreferences,
      );

  @override
  AppWindowController get appWindowController => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => _appWindowController ??= MacOSAppWindowController(),
    TargetPlatform.windows => _appWindowController ??= WindowsAppWindowController(),
    TargetPlatform.linux => _appWindowController ??= LinuxAppWindowController(),
    _ => throw UnsupportedError('AppWindowController is not supported on ${defaultTargetPlatform.name}'),
  };

  @override
  db.AppDatabase get database => _database ??= db.AppDatabase();

  @override
  Future<void> close() async {
    await Future.wait<void>([
      if (_releasesHttpClient case final client?) client.close(),
      if (_fileDownloadClient case final client?) client.close(),
    ]);
  }
}
