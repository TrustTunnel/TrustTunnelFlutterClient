import 'package:vpn/di/factory/repository_factory.dart';
import 'package:vpn/di/factory/service_factory.dart';
import 'package:vpn/feature/routing/routing/bloc/routing_bloc.dart';
import 'package:vpn/feature/routing/routing_details/bloc/routing_details_bloc.dart';
import 'package:vpn/feature/server/server_details/bloc/server_details_bloc.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/feature/settings/excluded_routes/bloc/excluded_routes_bloc.dart';
import 'package:vpn/feature/settings/query_log/bloc/query_log_bloc.dart';

abstract class BlocFactory {
  RoutingBloc routingBloc();
  ServersBloc serversBloc();
  ServerDetailsBloc serverDetailsBloc({int? serverId});
  RoutingDetailsBloc routingDetailsBloc({int? routingId});
  ExcludedRoutesBloc excludedRoutesBloc();
  QueryLogBloc queryLogBloc();
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
  ExcludedRoutesBloc excludedRoutesBloc() => ExcludedRoutesBloc(
        settingsRepository: _repositoryFactory.settingsRepository,
      );

  @override
  QueryLogBloc queryLogBloc() => QueryLogBloc(
        settingsRepository: _repositoryFactory.settingsRepository,
      );
}
