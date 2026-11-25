import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_code_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/data/repository/routing_repository.dart';
import 'package:trusttunnel/feature/routing/routing/controller/routing_states.dart';
import 'package:trusttunnel/feature/routing/routing/domain/service/routing_service.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class RoutingController extends BaseStateController<RoutingState> with SequentialControllerHandler {
  final RoutingRepository _repository;

  /// {@macro products_controller}
  RoutingController({
    required this._repository,
    super.initialState = const RoutingState.initial(),
  });

  /// Make a purchase for the given product ID
  Future<void> fetchRoutingProfiles() => handle(
    () async {
      setState(
        RoutingState.loading(
          fieldErrors: state.fieldErrors,
          routingList: state.routingList,
        ),
      );

      final result = await _repository.getAllProfiles();

      setState(
        RoutingState.idle(
          fieldErrors: state.fieldErrors,
          routingList: result,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> dataChanged({
    List<PresentationField>? fieldErrors,
  }) => handle(
    () {
      setState(
        RoutingState.idle(
          fieldErrors: fieldErrors ?? state.fieldErrors,
          routingList: state.routingList,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  /// Saves [name] if it is valid and unique among the other profile names.
  ///
  /// [defaultProfileName] is the current localized name of the built-in profile.
  Future<void> editName({
    required String id,
    required String name,
    required String defaultProfileName,
    required VoidCallback onSaved,
  }) => handle(
    () async {
      final routingProfile = state.routingList.firstWhereOrNull((element) => element.id == id);
      if (routingProfile == null) {
        throw const PresentationNotFoundException();
      }
      final otherNames = state.routingList
          .where((element) => element.id != id)
          .map(
            (profile) => RoutingProfileUtils.displayName(
              id: profile.id,
              name: profile.data.name,
              defaultProfileName: defaultProfileName,
            ),
          );

      final fieldErrors = RoutingService.validateRoutingProfileName(otherNames, name);

      if (fieldErrors.isNotEmpty) {
        setState(
          RoutingState.idle(
            fieldErrors: fieldErrors,
            routingList: state.routingList,
          ),
        );

        return;
      }

      final currentName = RoutingProfileUtils.displayName(
        id: id,
        name: routingProfile.data.name,
        defaultProfileName: defaultProfileName,
      );
      if (name == currentName) {
        // Keep the built-in name automatic when the user saves it without edits.
        onSaved();

        return;
      }

      await _repository.setProfileName(id: id, name: name);

      final updatedRoutingList = state.routingList.map(
        (element) => element.id == id
            ? element.copyWith(
                data: element.data.copyWith(
                  name: name,
                ),
              )
            : element,
      );

      setState(
        RoutingState.idle(
          fieldErrors: fieldErrors,
          routingList: updatedRoutingList.toList(),
        ),
      );

      onSaved.call();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> deleteProfile(String profileId, VoidCallback onDeleted) => handle(
    () async {
      await _repository.deleteProfile(id: profileId);
      final updatedRoutingList = state.routingList.where((element) => element.id != profileId).toList();
      setState(
        RoutingState.idle(
          fieldErrors: state.fieldErrors,
          routingList: updatedRoutingList,
        ),
      );
      onDeleted();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  PresentationException _parseException(Object? exception) =>
      ExceptionUtils.toPresentationException(exception: exception);

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      RoutingState.exception(
        exception: presentationException,
        fieldErrors: state.fieldErrors,
        routingList: state.routingList,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    RoutingState.idle(
      fieldErrors: state.fieldErrors,
      routingList: state.routingList,
    ),
  );
}
