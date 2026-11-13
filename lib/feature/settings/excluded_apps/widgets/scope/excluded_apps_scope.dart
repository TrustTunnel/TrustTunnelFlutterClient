import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/installed_app.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/controller/excluded_apps_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/controller/excluded_apps_states.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/scope/excluded_apps_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_apps/widgets/scope/excluded_apps_scope_controller.dart';

/// {@template excluded_apps_scope}
/// Application-level scope holding the per-app exclusion state.
/// {@endtemplate}
class ExcludedAppsScope extends StatefulWidget {
  final Widget child;

  const ExcludedAppsScope({
    required this.child,
    super.key,
  });

  static ExcludedAppsScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    ExcludedAppsAspect? aspect,
  }) => _InheritedExcludedAppsScope.controllerOf(
    context,
    listen: listen,
    aspect: aspect,
  ).controller;

  /// Returns the scope controller if a ExcludedAppsScope is above in the tree,
  /// otherwise `null`.
  static ExcludedAppsScopeController? maybeControllerOf(
    BuildContext context, {
    bool listen = false,
  }) {
    final element = context.getElementForInheritedWidgetOfExactType<_InheritedExcludedAppsScope>();

    return element == null ? null : (element.widget as _InheritedExcludedAppsScope).controller;
  }

  @override
  State<ExcludedAppsScope> createState() => _ExcludedAppsScopeState();
}

class _ExcludedAppsScopeState extends State<ExcludedAppsScope> implements ExcludedAppsScopeController {
  late final ExcludedAppsController _controller;

  @override
  List<String> get excludedApps => List<String>.unmodifiable(_controller.state.excludedApps);

  @override
  List<String> get initialExcludedApps => List<String>.unmodifiable(_controller.state.initialExcludedApps);

  @override
  List<InstalledApp> get installedApps => List<InstalledApp>.unmodifiable(_controller.state.installedApps);

  @override
  bool get appsLoading => _controller.state.appsLoading;

  @override
  bool get hasChanges => !listEquals(excludedApps, initialExcludedApps);

  @override
  bool get canSave => hasChanges;

  @override
  bool get loading => _controller.state.loading;

  @override
  PresentationException? get error => _controller.state.error;

  @override
  void Function() get fetchExcludedApps => _controller.fetch;

  @override
  void Function(List<String> excludedApps) get changeExcludedApps => (excludedApps) =>
      _controller.dataChanged(excludedApps: excludedApps);

  @override
  void Function(String packageName) get toggleApp => _controller.toggleApp;

  @override
  void Function(VoidCallback onSaved) get submit => _controller.submit;

  @override
  void initState() {
    super.initState();
    final repositoryFactory = context.repositoryFactory;

    _controller = ExcludedAppsController(repositoryFactory.excludedAppsRepository);

    _controller.fetch();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<ExcludedAppsController, ExcludedAppsState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedExcludedAppsScope(
      controller: this,
      state: state,
      child: widget.child,
    ),
  );

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _controller.removeListener(listener);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedExcludedAppsScope extends InheritedModel<ExcludedAppsAspect> {
  final ExcludedAppsScopeController controller;

  final ExcludedAppsState state;

  const _InheritedExcludedAppsScope({
    required this.controller,
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedExcludedAppsScope oldWidget) => state != oldWidget.state;

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedExcludedAppsScope oldWidget,
    Set<ExcludedAppsAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    for (final aspect in dependencies) {
      switch (aspect) {
        case ExcludedAppsAspect.loading:
          if (state.loading != oldWidget.state.loading) return true;
        case ExcludedAppsAspect.data:
          if (state != oldWidget.state) return true;
      }
    }

    return false;
  }

  static _InheritedExcludedAppsScope controllerOf(
    BuildContext context, {
    bool listen = true,
    ExcludedAppsAspect? aspect,
  }) => _scope(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedExcludedAppsScope? _scope(
    BuildContext context, {
    bool listen = true,
    ExcludedAppsAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedExcludedAppsScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedExcludedAppsScope>()?.widget
            as _InheritedExcludedAppsScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<ExcludedAppsAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
