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

  @override
  ServerRepository get serverRepository => _serverRepository ??= ServerRepositoryImpl(
    serverDataSource: _dependencyFactory.serverDataSource,
    routingDataSource: _dependencyFactory.routingDataSource,
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
}
