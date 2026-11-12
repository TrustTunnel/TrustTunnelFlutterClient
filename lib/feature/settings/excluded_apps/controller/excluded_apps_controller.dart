import 'dart:ui';

import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/data/repository/excluded_apps_repository.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/controller/excluded_apps_states.dart';

/// {@template excluded_apps_controller}
/// Controller for managing the per-app VPN exclusions.
/// {@endtemplate}
final class ExcludedAppsController extends BaseStateController<ExcludedAppsState>
    with SequentialControllerHandler {
  final ExcludedAppsRepository _repository;

  /// {@macro excluded_apps_controller}
  ExcludedAppsController(
    this._repository, {
    super.initialState = const ExcludedAppsState.initial(),
  });

  /// Loads the persisted exclusion list and the installed applications.
  void fetch() {
    handle(
      () async {
        setState(
          ExcludedAppsState.loading(
            excludedApps: state.excludedApps,
            initialExcludedApps: state.initialExcludedApps,
            installedApps: state.installedApps,
            appsLoading: true,
          ),
        );

        final initialExcludedApps = await _repository.getExcludedApps();

        setState(
          ExcludedAppsState.idle(
            excludedApps: initialExcludedApps,
            initialExcludedApps: initialExcludedApps,
            installedApps: state.installedApps,
            appsLoading: true,
          ),
        );

        await _fetchInstalledApps();
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  Future<void> _fetchInstalledApps() async {
    try {
      final installedApps = await _repository.getInstalledApps();
      setState(
        ExcludedAppsState.idle(
          excludedApps: state.excludedApps,
          initialExcludedApps: state.initialExcludedApps,
          installedApps: installedApps,
          appsLoading: false,
        ),
      );
    } catch (error) {
      // The selection list is an optional convenience; keep the screen usable.
      setState(
        ExcludedAppsState.idle(
          excludedApps: state.excludedApps,
          initialExcludedApps: state.initialExcludedApps,
          installedApps: const [],
          appsLoading: false,
        ),
      );
    }
  }

  /// Replaces the editable buffer of excluded packages.
  void dataChanged({List<String>? excludedApps}) => handle(
    () {
      setState(
        ExcludedAppsState.idle(
          excludedApps: excludedApps ?? state.excludedApps,
          initialExcludedApps: state.initialExcludedApps,
          installedApps: state.installedApps,
          appsLoading: state.appsLoading,
        ),
      );
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  /// Checks or unchecks a single package.
  void toggleApp(String packageName) => dataChanged(
    excludedApps: state.excludedApps.contains(packageName)
        ? state.excludedApps.where((app) => app != packageName).toList()
        : [...state.excludedApps, packageName],
  );

  /// Persists the current buffer.
  void submit(VoidCallback onSaved) => handle(
    () async {
      setState(
        ExcludedAppsState.loading(
          excludedApps: state.excludedApps,
          initialExcludedApps: state.initialExcludedApps,
          installedApps: state.installedApps,
          appsLoading: state.appsLoading,
        ),
      );

      await _repository.setExcludedApps(state.excludedApps);

      setState(
        ExcludedAppsState.idle(
          excludedApps: state.excludedApps,
          initialExcludedApps: state.excludedApps,
          installedApps: state.installedApps,
          appsLoading: state.appsLoading,
        ),
      );

      onSaved();
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = ExceptionUtils.toPresentationException(exception: error);

    setState(
      ExcludedAppsState.exception(
        exception: presentationException,
        excludedApps: state.excludedApps,
        initialExcludedApps: state.initialExcludedApps,
        installedApps: state.installedApps,
        appsLoading: state.appsLoading,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    ExcludedAppsState.idle(
      excludedApps: state.excludedApps,
      initialExcludedApps: state.initialExcludedApps,
      installedApps: state.installedApps,
      appsLoading: state.appsLoading,
    ),
  );
}
