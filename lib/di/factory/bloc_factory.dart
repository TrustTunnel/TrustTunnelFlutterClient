import 'package:vpn/di/factory/repository_factory.dart';
import 'package:vpn/di/factory/service_factory.dart';
import 'package:vpn/feature/routing/routing/bloc/routing_bloc.dart';
import 'package:vpn/feature/routing/routing_details/bloc/routing_details_bloc.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/feature/settings/settings_query_log/bloc/settings_query_log_bloc.dart';

abstract class BlocFactory {
  RoutingBloc routingBloc();
  ServersBloc serversBloc();
  ServerDetailsBloc serverDetailsBloc({int? serverId});
  RoutingDetailsBloc routingDetailsBloc({int? routingId});
  SettingsQueryLogBloc settingsQueryLogBloc();
}

class BlocFactoryImpl implements BlocFactory {
  final RepositoryFactory _repositoryFactory;
  final ServiceFactory _serviceFactory;

  BlocFactoryImpl({
    required RepositoryFactory repositoryFactory,
    required ServiceFactory serviceFactory,
  })  : _serviceFactory = serviceFactory,
        _repositoryFactory = repositoryFactory;

  @override
  RoutingBloc routingBloc() => RoutingBloc();

  @override
  ServersBloc serversBloc() => ServersBloc(
        serverRepository: _repositoryFactory.serverRepository,
      );

  @override
  ServerDetailsBloc serverDetailsBloc({
    int? serverId,
  }) =>
      ServerDetailsBloc(
        serverId: serverId,
        serverRepository: _repositoryFactory.serverRepository,
        serverDetailsService: _serviceFactory.serverDetailsService,
      );

  @override
  RoutingDetailsBloc routingDetailsBloc({
    int? routingId,
  }) =>
      RoutingDetailsBloc(
        routingId: routingId,
      );

  @override
  SettingsQueryLogBloc settingsQueryLogBloc() => SettingsQueryLogBloc();
}
