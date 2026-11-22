import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_code_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/utils/server_name_utils.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
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

  Future<void> editName({
    required String id,
    required String name,
    required VoidCallback onSaved,
  }) => handle(
    () async {
      final routingProfile = state.routingList.firstWhereOrNull((element) => element.id == id);
      if (routingProfile == null) {
        throw const PresentationNotFoundException();
      }
      final otherProfiles = state.routingList
          .where((element) => element.id != id)
          .map((element) => element.data)
          .toSet();

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

  void duplicateProfile({
    required String profileId,
    required String Function(String name, int number) numberedName,
    ValueChanged<RoutingProfile>? onDuplicated,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(
        RoutingState.loading(
          fieldErrors: state.fieldErrors,
          routingList: state.routingList,
        ),
      );

      final currentProfiles = await _repository.getAllProfiles();
      final originalProfile = currentProfiles.firstWhere(
        (profile) => profile.id == profileId,
        orElse: () => throw const PresentationNotFoundException(),
      );

      final duplicateName = ServerNameUtils.findAvailable(
        baseName: originalProfile.data.name,
        otherNames: currentProfiles.map((profile) => profile.data.name),
        preferredName: numberedName(originalProfile.data.name.trim(), 0),
        numberedName: numberedName,
      );

      final duplicate = await _repository.addNewProfile(
        originalProfile.data.copyWith(name: duplicateName),
      );

      final profiles = await _repository.getAllProfiles();
      setState(
        RoutingState.idle(
          fieldErrors: state.fieldErrors,
          routingList: profiles,
        ),
      );

      if (!isDisposed) onDuplicated?.call(duplicate);
    },
    errorHandler: (error, stackTrace) {
      _onError(error, stackTrace);
      onError?.call();
    },
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
