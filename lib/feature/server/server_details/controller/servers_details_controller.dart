import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_base_error.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:trusttunnel/data/repository/routing_repository.dart';
import 'package:trusttunnel/data/repository/server_repository.dart';
import 'package:trusttunnel/feature/server/server_details/controller/servers_details_states.dart';
import 'package:trusttunnel/feature/server/server_details/domain/service/server_details_service.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class ServerDetailsController extends BaseStateController<ServerDetailsState> with SequentialControllerHandler {
  final ServerRepository _repository;
  final RoutingRepository _routingRepository;
  final ServerDetailsService _detailsService;
  final int? _serverId;

  /// {@macro products_controller}
  ServerDetailsController({
    required ServerRepository repository,
    required RoutingRepository routingRepository,
    required ServerDetailsService detailsService,
    required int? serverId,
    super.initialState = const ServerDetailsState.initial(),
  }) : _repository = repository,
       _routingRepository = routingRepository,
       _detailsService = detailsService,
       _serverId = serverId;

  /// Make a purchase for the given product ID
  void fetch() {
    handle(
      () async {
        setState(
          ServerDetailsState.loading(
            data: state.data,
            initialData: state.initialData,
            fieldErrors: state.fieldErrors,
            routingProfiles: state.routingProfiles,
          ),
        );

        final profiles = await _routingRepository.getAllProfiles();

        if (_serverId == null) {
          setState(
            ServerDetailsState.idle(
              data: state.data,
              initialData: state.initialData,
              fieldErrors: state.fieldErrors,
              routingProfiles: profiles,
            ),
          );

          return;
        }

        final server = await _repository.getServerById(id: _serverId);

        if (server == null) {
          throw PresentationNotFoundError();
        }

        final data = _detailsService.toServerDetailsData(server: server);

        setState(
          ServerDetailsState.idle(
            data: data,
            initialData: data,
            fieldErrors: state.fieldErrors,
            routingProfiles: profiles,
          ),
        );
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  void dataChanged({
    String? serverName,
    String? ipAddress,
    String? domain,
    String? username,
    String? password,
    VpnProtocol? protocol,
    int? routingProfileId,
    List<String>? dnsServers,
  }) => handle(() {
    setState(
      ServerDetailsState.idle(
        fieldErrors: state.fieldErrors,
        initialData: state.initialData,
        routingProfiles: state.routingProfiles,

        data: state.data.copyWith(
          serverName: serverName ?? state.data.serverName,
          ipAddress: ipAddress ?? state.data.ipAddress,
          domain: domain ?? state.data.domain,
          username: username ?? state.data.username,
          password: password ?? state.data.password,
          protocol: protocol ?? state.data.protocol,
          routingProfileId: routingProfileId ?? state.data.routingProfileId,
          dnsServers: dnsServers ?? state.data.dnsServers,
        ),
      ),
    );
  });

  void submit(void Function(String name) onSaved) => handle(
    () async {
      setState(
        ServerDetailsState.loading(
          data: state.data,
          initialData: state.initialData,
          fieldErrors: state.fieldErrors,
          routingProfiles: state.routingProfiles,
        ),
      );

      final servers = await _repository.getAllServers();

      final List<PresentationField> filedErrors = _detailsService.validateData(
        data: state.data,
        otherServersNames: servers.map((server) => server.name).toSet()
          ..remove(
            state.initialData.serverName,
          ),
      );

      if (filedErrors.isNotEmpty) {
        setState(
          ServerDetailsState.idle(
            data: state.data,
            initialData: state.initialData,
            fieldErrors: filedErrors.toList(),
            routingProfiles: state.routingProfiles,
          ),
        );

        return;
      }

      if (_serverId != null) {
        await _repository.setNewServer(
          id: _serverId,
          request: (
            dnsServers: state.data.dnsServers,
            name: state.data.serverName,
            ipAddress: state.data.ipAddress,
            domain: state.data.domain,
            username: state.data.username,
            password: state.data.password,
            vpnProtocol: state.data.protocol,
            routingProfileId: state.data.routingProfileId,
          ),
        );
      } else {
        await _repository.addNewServer(
          request: (
            dnsServers: state.data.dnsServers,
            name: state.data.serverName,
            ipAddress: state.data.ipAddress,
            domain: state.data.domain,
            username: state.data.username,
            password: state.data.password,
            vpnProtocol: state.data.protocol,
            routingProfileId: state.data.routingProfileId,
          ),
        );
      }
      onSaved(state.data.serverName);
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void delete(
    void Function(String name) onDeleted,
  ) => handle(
    () async {
      setState(
        ServerDetailsState.loading(
          data: state.data,
          initialData: state.initialData,
          fieldErrors: state.fieldErrors,
          routingProfiles: state.routingProfiles,
        ),
      );

      await _repository.removeServer(serverId: _serverId!);

      onDeleted(state.data.serverName);
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  PresentationError _parseException(Object? exception) => ErrorUtils.toPresentationError(exception: exception);

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      ServerDetailsState.exception(
        exception: presentationException,
        data: state.data,
        initialData: state.initialData,
        fieldErrors: state.fieldErrors,
        routingProfiles: state.routingProfiles,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    ServerDetailsState.idle(
      data: state.data,
      initialData: state.initialData,
      fieldErrors: state.fieldErrors,
      routingProfiles: state.routingProfiles,
    ),
  );
}
