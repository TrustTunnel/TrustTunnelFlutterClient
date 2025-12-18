import 'package:flutter/material.dart';
import 'package:trusttunnel/common/theme/light_theme.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/local_sources/routing_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/server_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/local_sources/settings_datasource_impl.dart';
import 'package:trusttunnel/data/datasources/native_sources/vpn_datasource.dart';
import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/datasources/settings_datasource.dart';
import 'package:trusttunnel/data/datasources/vpn_datasource.dart';
import 'package:vpn_plugin/vpn_plugin.dart';

abstract class DependencyFactory {
  ThemeData get lightThemeData;

  VpnPlugin get vpnPlugin;

  SettingsDataSource get settingsDataSource;

  ServerDataSource get serverDataSource;

  RoutingDataSource get routingDataSource;

  VpnDataSource get vpnDataSource;

  db.AppDatabase get database;
}

class DependencyFactoryImpl implements DependencyFactory {
  ThemeData? _lightThemeData;

  VpnPlugin? _vpnPlugin;

  SettingsDataSource? _settingsDataSource;

  ServerDataSource? _serverDataSource;

  RoutingDataSource? _routingDataSource;

  VpnDataSource? _vpnDataSource;

  db.AppDatabase? _database;

  @override
  ThemeData get lightThemeData => _lightThemeData ??= LightTheme().data;

  @override
  VpnPlugin get vpnPlugin => _vpnPlugin ??= VpnPluginImpl();

  @override
  SettingsDataSource get settingsDataSource => _settingsDataSource ??= SettingsDataSourceImpl(database: database);

  @override
  ServerDataSource get serverDataSource => _serverDataSource ??= ServerDataSourceImpl(database: database);

  @override
  RoutingDataSource get routingDataSource => _routingDataSource ??= RoutingDataSourceImpl(database);

  @override
  VpnDataSource get vpnDataSource => _vpnDataSource ??= VpnDataSourceImpl(vpnPlugin: vpnPlugin);

  @override
  db.AppDatabase get database => _database ??= db.AppDatabase();
}
