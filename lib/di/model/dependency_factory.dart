import 'package:adguard_logger/adguard_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/common/logging/model/logging_settings.dart';
import 'package:trusttunnel/common/theme/light_theme.dart';
import 'package:trusttunnel/common/utils/certificate_encoders.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/app_state_logging_datasource.dart';
import 'package:trusttunnel/data/datasources/certificate_datasource.dart';
import 'package:trusttunnel/data/datasources/local_sources/app_state_logging_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/certificate_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/logging_settings_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/logs_archive_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/logs_export_destination_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/logs_local_source_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/routing_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/server_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/settings_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_archive_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_export_destination_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_local_source.dart';
import 'package:trusttunnel/data/datasources/native_sources/vpn_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/datasources/settings_datasource.dart';
import 'package:trusttunnel/data/datasources/vpn_datasource.dart';
import 'package:vpn_plugin/deep_link_manager.dart';
import 'package:vpn_plugin/vpn_plugin.dart';

abstract class DependencyFactory {
  abstract final SharedPreferences sharedPreferences;

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

  FileLogAppender get fileLogAppender;

  LogsLocalSource get exportLogsLocalSource;

  LogsArchiveDataSource get logsArchiveDataSource;

  LogsExportDestinationDataSource get logsExportDestinationDataSource;

  db.AppDatabase get database;
}

class DependencyFactoryImpl implements DependencyFactory {
  DependencyFactoryImpl({
    required this.sharedPreferences,
  });

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

  FileLogAppender? _fileLogAppender;

  LogsLocalSource? _exportLogsLocalSource;

  LogStorage? _logStorage;

  String? _logDirectoryPath;

  LogsArchiveDataSource? _logsArchiveDataSource;

  LogsExportDestinationDataSource? _logsExportDestinationDataSource;

  db.AppDatabase? _database;

  @override
  SharedPreferences sharedPreferences;

  @override
  ThemeData get lightThemeData => _lightThemeData ??= LightTheme().data;

  @override
  VpnPlugin get vpnPlugin => _vpnPlugin ??= VpnPluginImpl();

  @override
  DeepLinkManager get deepLinkManager => _deepLinkManager ??= DeepLinkManagerImpl();

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
        settingsProvider: () => const LoggingSettings(),
      );

  @override
  FileLogAppender get fileLogAppender => _fileLogAppender!;

  @override
  LogsLocalSource get exportLogsLocalSource => _exportLogsLocalSource ??= LogsLocalSourceImpl(
    logAppender: fileLogAppender,
    appStateLoggingDataSource: appStateLoggingDataSource,
    filePicker: FilePicker.platform,
    logStorage: logStorage,
  );

  @override
  LogsArchiveDataSource get logsArchiveDataSource => _logsArchiveDataSource ??= LogsArchiveDataSourceImpl();

  @override
  LogsExportDestinationDataSource get logsExportDestinationDataSource =>
      _logsExportDestinationDataSource ??= LogsExportDestinationDataSourceImpl(
        filePicker: FilePicker.platform,
      );

  @override
  db.AppDatabase get database => _database ??= db.AppDatabase();

  set fileLogAppender(FileLogAppender value) => _fileLogAppender = value;

  LogStorage get logStorage => _logStorage!;

  set logStorage(LogStorage value) => _logStorage = value;

  String get logDirectoryPath => _logDirectoryPath!;

  set logDirectoryPath(String value) => _logDirectoryPath = value;
}
