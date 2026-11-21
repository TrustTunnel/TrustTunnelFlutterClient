import 'dart:ui';

import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/repository/settings_repository.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/controller/excluded_routes_states.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class ExcludedRoutesController extends BaseStateController<ExcludedRoutesState> with SequentialControllerHandler {
  final SettingsRepository _repository;

  /// {@macro products_controller}
  ExcludedRoutesController({
    required this._repository,
    super.initialState = const ExcludedRoutesState.initial(),
  });

  /// Make a purchase for the given product ID
  void fetch() {
    handle(
      () async {
        setState(
          ExcludedRoutesState.loading(
            excludedRoutes: state.excludedRoutes,
            hasInvalidRoutes: state.hasInvalidRoutes,
            initialExcludedRoutes: state.initialExcludedRoutes,
            defaultExcludedRoutes: state.defaultExcludedRoutes,
          ),
        );

        final initialExcludedRoutes = await _repository.getExcludedRoutes();
        final defaultExcludedRoutes = await _repository.getDefaultExcludedRoutes();

        setState(
          ExcludedRoutesState.idle(
            excludedRoutes: initialExcludedRoutes,
            initialExcludedRoutes: initialExcludedRoutes,
            defaultExcludedRoutes: defaultExcludedRoutes,
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
  }) => handle(
    () {
      setState(
        ExcludedRoutesState.idle(
          excludedRoutes: excludedRoutes ?? state.excludedRoutes,
          initialExcludedRoutes: initialExcludedRoutes ?? state.initialExcludedRoutes,
          defaultExcludedRoutes: state.defaultExcludedRoutes,
          hasInvalidRoutes: hasInvalidRules ?? state.hasInvalidRoutes,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  /// Replaces the current routes with the factory defaults.
  ///
  /// Only updates the form state; the changes are persisted on [submit].
  void resetToDefault() => dataChanged(
    excludedRoutes: state.defaultExcludedRoutes,
    hasInvalidRules: false,
  );

  void submit(VoidCallback onSaved) => handle(
    () async {
      setState(
        ExcludedRoutesState.loading(
          excludedRoutes: state.excludedRoutes,
          hasInvalidRoutes: state.hasInvalidRoutes,
          initialExcludedRoutes: state.initialExcludedRoutes,
          defaultExcludedRoutes: state.defaultExcludedRoutes,
        ),
      );

      await _repository.setExcludedRoutes(state.excludedRoutes);

      setState(
        ExcludedRoutesState.idle(
          excludedRoutes: state.excludedRoutes,
          initialExcludedRoutes: state.excludedRoutes,
          defaultExcludedRoutes: state.defaultExcludedRoutes,
          hasInvalidRoutes: false,
        ),
      );

      onSaved();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  PresentationException _parseException(Object? exception) =>
      ExceptionUtils.toPresentationException(exception: exception);

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      ExcludedRoutesState.exception(
        exception: presentationException,
        excludedRoutes: state.excludedRoutes,
        hasInvalidRoutes: state.hasInvalidRoutes,
        initialExcludedRoutes: state.initialExcludedRoutes,
        defaultExcludedRoutes: state.defaultExcludedRoutes,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    ExcludedRoutesState.idle(
      excludedRoutes: state.excludedRoutes,
      hasInvalidRoutes: state.hasInvalidRoutes,
      initialExcludedRoutes: state.initialExcludedRoutes,
      defaultExcludedRoutes: state.defaultExcludedRoutes,
    ),
  );
}
