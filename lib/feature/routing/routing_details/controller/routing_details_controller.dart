import 'dart:ui';

import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_base_error.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile_data.dart';
import 'package:trusttunnel/data/repository/routing_repository.dart';
import 'package:trusttunnel/feature/routing/routing_details/controller/routing_details_states.dart';
import 'package:trusttunnel/feature/routing/routing_details/domain/service/routing_details_service.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class RoutingDetailsController extends BaseStateController<RoutingDetailsState> with SequentialControllerHandler {
  final RoutingRepository _repository;
  final RoutingDetailsService _detailsService;
  final String? _profileId;

  /// {@macro products_controller}
  RoutingDetailsController({
    required RoutingRepository repository,
    required RoutingDetailsServiceImpl detailsService,
    required String? profileId,
    super.initialState = const RoutingDetailsState.initial(),
  }) : _repository = repository,
       _detailsService = detailsService,
       _profileId = profileId;

  /// Make a purchase for the given product ID
  void fetch() {
    handle(
      () async {
        setState(
          RoutingDetailsState.loading(
            data: state.data,
            initialData: state.initialData,
            hasInvalidRules: state.hasInvalidRules,
          ),
        );

        if (_profileId == null) {
          final profiles = await _repository.getAllProfiles();
          setState(
            RoutingDetailsState.idle(
              data: state.data.copyWith(
                name: _detailsService.getNewProfileName(profiles.map((p) => p.data.name).toSet()),
              ),
              initialData: state.initialData,
              hasInvalidRules: state.hasInvalidRules,
            ),
          );

          return;
        }

        final routingProfile = await _repository.getProfileById(id: _profileId);
        if (routingProfile == null) {
          throw PresentationNotFoundError();
        }

        setState(
          RoutingDetailsState.idle(
            data: routingProfile.data,
            initialData: routingProfile.data,
            hasInvalidRules: state.hasInvalidRules,
          ),
        );
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  void dataChanged({
    RoutingProfileData? data,
    RoutingProfileData? initialData,
    bool? hasInvalidRules,
    String? name,
  }) => handle(() {
    setState(
      RoutingDetailsState.idle(
        data: data ?? state.data,
        hasInvalidRules: hasInvalidRules ?? state.hasInvalidRules,
        initialData: initialData ?? state.initialData,
      ),
    );
  });

  void submit(VoidCallback onSaved) => handle(
    () async {
      var profileId = _profileId;
      if (profileId == null) {
        profileId = (await _repository.addNewProfile(
          state.data,
        )).id;
      } else {
        Future.wait([
          _repository.setDefaultRoutingMode(id: profileId, mode: state.data.defaultMode),

          _repository.setRules(
            id: profileId,
            mode: RoutingMode.bypass,
            rules: state.data.bypassRules,
          ),

          _repository.setRules(
            id: profileId,
            mode: RoutingMode.vpn,
            rules: state.data.vpnRules,
          ),
        ]);
      }

      onSaved();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void clearRules(
    VoidCallback onCleared,
  ) => handle(
    () async {
      setState(
        RoutingDetailsState.loading(
          data: state.data,
          initialData: state.initialData,
          hasInvalidRules: state.hasInvalidRules,
        ),
      );

      await Future.wait([
        _repository.setRules(
          id: _profileId!,
          mode: RoutingMode.vpn,
          rules: [],
        ),
        _repository.setRules(
          id: _profileId,
          mode: RoutingMode.bypass,
          rules: [],
        ),
      ]);

      setState(
        RoutingDetailsState.idle(
          data: state.data.copyWith(
            vpnRules: [],
            bypassRules: [],
          ),
          initialData: state.initialData.copyWith(
            vpnRules: [],
            bypassRules: [],
          ),
          hasInvalidRules: false,
        ),
      );

      onCleared();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void changeDefaultRoutingMode(RoutingMode mode, VoidCallback onChanged) => handle(
    () async {
      setState(
        RoutingDetailsState.loading(
          data: state.data,
          initialData: state.initialData,
          hasInvalidRules: state.hasInvalidRules,
        ),
      );

      await _repository.setDefaultRoutingMode(id: _profileId!, mode: mode);

      setState(
        RoutingDetailsState.idle(
          data: state.data.copyWith(defaultMode: mode),
          initialData: state.initialData.copyWith(defaultMode: mode),
          hasInvalidRules: state.hasInvalidRules,
        ),
      );

      Future.delayed(Duration.zero).then((_) => onChanged());
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  PresentationError _parseException(Object? exception) => ErrorUtils.toPresentationError(exception: exception);

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      RoutingDetailsState.exception(
        exception: presentationException,
        data: state.data,
        initialData: state.initialData,
        hasInvalidRules: state.hasInvalidRules,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    RoutingDetailsState.idle(
      data: state.data,
      initialData: state.initialData,
      hasInvalidRules: state.hasInvalidRules,
    ),
  );
}
