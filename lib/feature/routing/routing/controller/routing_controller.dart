import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_base_error.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
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
    required RoutingRepository repository,
    super.initialState = const RoutingState.initial(),
  }) : _repository = repository;

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

  Future<void> editName({
    required int id,
    required String name,
    required VoidCallback onSaved,
  }) => handle(
    () async {
      final routingProfile = state.routingList.firstWhereOrNull((element) => element.id == id);
      if (routingProfile == null) {
        throw PresentationNotFoundError();
      }
      final otherProfiles = state.routingList.where((element) => element.id != id).toSet();

      final fieldErrors = RoutingService.validateRoutingProfileName(otherProfiles, name);

      if (fieldErrors.isNotEmpty) {
        setState(
          RoutingState.idle(
            fieldErrors: fieldErrors,
            routingList: state.routingList,
          ),
        );

        return;
      }

      await _repository.setProfileName(
        id: id,
        name: name,
      );

      final updatedRoutingList = state.routingList.map(
        (element) => element.id == id ? element.copyWith(name: name) : element,
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

  Future<void> deleteProfile(int profileId, VoidCallback onDeleted) => handle(() async {
    await _repository.deleteProfile(id: profileId);
    final updatedRoutingList = state.routingList.where((element) => element.id != profileId).toList();
    setState(
      RoutingState.idle(
        fieldErrors: state.fieldErrors,
        routingList: updatedRoutingList,
      ),
    );
    onDeleted();
  });

  PresentationError _parseException(Object? exception) => ErrorUtils.toPresentationError(exception: exception);

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
