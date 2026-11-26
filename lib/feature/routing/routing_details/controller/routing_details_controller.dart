import 'dart:ui';

import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_code_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:trusttunnel/data/model/routing_profile_data.dart';
import 'package:trusttunnel/data/repository/routing_repository.dart';
import 'package:trusttunnel/feature/routing/routing_details/controller/routing_details_states.dart';
import 'package:trusttunnel/feature/routing/routing_details/domain/service/routing_details_service.dart';
import 'package:trusttunnel/feature/routing/routing_details/model/routing_profile_name.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class RoutingDetailsController extends BaseStateController<RoutingDetailsState> with SequentialControllerHandler {
  final RoutingRepository _repository;
  final RoutingDetailsService _detailsService;
  final String? _profileId;

  /// {@macro products_controller}
  RoutingDetailsController({
    required this._repository,
    required RoutingDetailsServiceImpl this._detailsService,
    required this._profileId,
    super.initialState = const RoutingDetailsState.initial(),
  });

  /// Loads the profile or generates a name for a new profile.
  ///
  /// [defaultProfileName] is the localized name of the built-in profile.
  /// [formatNewProfileName] formats a candidate name for a given index.
  void fetch({
    required String defaultProfileName,
    required String Function(int number) formatNewProfileName,
  }) {
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
          final occupiedNames = profiles.map(
            (profile) => RoutingProfileUtils.displayName(
              name: profile.data.name,
              defaultProfileName: defaultProfileName,
            ),
          );
          final name = RoutingProfileName.custom(
            _detailsService.getNewProfileName(
              occupiedNames: occupiedNames,
              formatName: formatNewProfileName,
            ),
          );
          final data =
              state.data?.copyWith(name: name) ??
              RoutingProfileData(
                name: name,
                defaultMode: RoutingMode.vpn,
                bypassRules: const [],
                vpnRules: const [],
              );
          setState(
            RoutingDetailsState.idle(
              data: data,
              initialData: state.initialData,
              hasInvalidRules: state.hasInvalidRules,
            ),
          );

          return;
        }

        final routingProfile = await _repository.getProfileById(id: _profileId);
        if (routingProfile == null) {
          throw const PresentationNotFoundException();
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
  }) => handle(
    () {
      setState(
        RoutingDetailsState.idle(
          data: data ?? state.data,
          hasInvalidRules: hasInvalidRules ?? state.hasInvalidRules,
          initialData: initialData ?? state.initialData,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  void submit(VoidCallback onSaved) => handle(
    () async {
      final data = state.data;
      if (data == null) {
        return;
      }

      final profileId = _profileId;
      if (profileId == null) {
        await _repository.addNewProfile(data);
      } else {
        await Future.wait([
          _repository.setDefaultRoutingMode(id: profileId, mode: data.defaultMode),

          _repository.setRules(
            id: profileId,
            mode: RoutingMode.bypass,
            rules: data.bypassRules,
          ),

          _repository.setRules(
            id: profileId,
            mode: RoutingMode.vpn,
            rules: data.vpnRules,
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
      final data = state.data;
      final profileId = _profileId;
      if (data == null || profileId == null) {
        return;
      }

      setState(
        RoutingDetailsState.loading(
          data: state.data,
          initialData: state.initialData,
          hasInvalidRules: state.hasInvalidRules,
        ),
      );

      await Future.wait([
        _repository.setRules(
          id: profileId,
          mode: RoutingMode.vpn,
          rules: [],
        ),
        _repository.setRules(
          id: profileId,
          mode: RoutingMode.bypass,
          rules: [],
        ),
      ]);

      setState(
        RoutingDetailsState.idle(
          data: data.copyWith(
            vpnRules: [],
            bypassRules: [],
          ),
          initialData: state.initialData?.copyWith(
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
      final data = state.data;
      final profileId = _profileId;
      if (data == null || profileId == null) {
        return;
      }

      setState(
        RoutingDetailsState.loading(
          data: state.data,
          initialData: state.initialData,
          hasInvalidRules: state.hasInvalidRules,
        ),
      );

      await _repository.setDefaultRoutingMode(id: profileId, mode: mode);

      setState(
        RoutingDetailsState.idle(
          data: data.copyWith(defaultMode: mode),
          initialData: state.initialData?.copyWith(defaultMode: mode),
          hasInvalidRules: state.hasInvalidRules,
        ),
      );

      onChanged();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  PresentationException _parseException(Object? exception) =>
      ExceptionUtils.toPresentationException(exception: exception);

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
