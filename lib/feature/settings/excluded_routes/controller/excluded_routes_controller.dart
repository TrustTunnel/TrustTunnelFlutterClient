import 'dart:ui';

import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/repository/settings_repository.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/controller/excluded_routes_states.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class ExcludedRoutesController extends BaseStateController<ExcludedRoutesState> with SequentialControllerHandler {
  final SettingsRepository _repository;

  /// {@macro products_controller}
  ExcludedRoutesController({
    required SettingsRepository repository,
    super.initialState = const ExcludedRoutesState.initial(),
  }) : _repository = repository;

  /// Make a purchase for the given product ID
  void fetch() {
    handle(
      () async {
        setState(
          ExcludedRoutesState.loading(
            excludedRoutes: state.excludedRoutes,
            hasInvalidRoutes: state.hasInvalidRoutes,
            initialExcludedRoutes: state.initialExcludedRoutes,
          ),
        );

        final initialExcludedRoutes = await _repository.getExcludedRoutes();

        setState(
          ExcludedRoutesState.idle(
            excludedRoutes: initialExcludedRoutes,
            initialExcludedRoutes: initialExcludedRoutes,
            hasInvalidRoutes: false,
          ),
        );
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  void dataChanged({
    List<String>? excludedRoutes,
    List<String>? initialExcludedRoutes,
    bool? hasInvalidRules,
  }) => handle(() {
    setState(
      ExcludedRoutesState.idle(
        excludedRoutes: excludedRoutes ?? state.excludedRoutes,
        initialExcludedRoutes: initialExcludedRoutes ?? state.initialExcludedRoutes,
        hasInvalidRoutes: hasInvalidRules ?? state.hasInvalidRoutes,
      ),
    );
  });

  void submit(VoidCallback onSaved) => handle(
    () async {
      setState(
        ExcludedRoutesState.loading(
          excludedRoutes: state.excludedRoutes,
          hasInvalidRoutes: state.hasInvalidRoutes,
          initialExcludedRoutes: state.initialExcludedRoutes,
        ),
      );

      await _repository.setExcludedRoutes(state.excludedRoutes);

      setState(
        ExcludedRoutesState.idle(
          excludedRoutes: state.excludedRoutes,
          initialExcludedRoutes: state.excludedRoutes,
          hasInvalidRoutes: false,
        ),
      );

      onSaved();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  PresentationError _parseException(Object? exception) => ErrorUtils.toPresentationError(exception: exception);

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      ExcludedRoutesState.exception(
        exception: presentationException,
        excludedRoutes: state.excludedRoutes,
        hasInvalidRoutes: state.hasInvalidRoutes,
        initialExcludedRoutes: state.initialExcludedRoutes,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    ExcludedRoutesState.idle(
      excludedRoutes: state.excludedRoutes,
      hasInvalidRoutes: state.hasInvalidRoutes,
      initialExcludedRoutes: state.initialExcludedRoutes,
    ),
  );
}
