import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/controller/excluded_routes_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/controller/excluded_routes_states.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope_controller.dart';

class ExcludedRoutesScope extends StatefulWidget {
  final Widget child;

  const ExcludedRoutesScope({
    required this.child,
    super.key,
  });

  static ExcludedRoutesScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    ExcludedRoutesAspect? aspect,
  }) => _InheritedExcludedRoutesScope.controllerOf(
    context,
    listen: listen,
    aspect: aspect,
  ).controller;

  @override
  State<ExcludedRoutesScope> createState() => _ExcludedRoutesScopeState();
}

class _ExcludedRoutesScopeState extends State<ExcludedRoutesScope> implements ExcludedRoutesScopeController {
  late final ExcludedRoutesController _controller;

  @override
  List<String> get excludedRoutes => List<String>.unmodifiable(_controller.state.excludedRoutes);

  @override
  List<String> get initialExcludedRoutes => List<String>.unmodifiable(_controller.state.initialExcludedRoutes);

  @override
  bool get hasInvalidRoutes => _controller.state.hasInvalidRoutes;

  @override
  bool get hasChanges => !listEquals(excludedRoutes, initialExcludedRoutes);

  @override
  bool get canSave => hasChanges && (!hasInvalidRoutes || excludedRoutes.isEmpty);

  @override
  bool get loading => _controller.state.loading;

  @override
  PresentationException? get error => _controller.state.error;

  @override
  void Function() get fetchExcludedRoutes => _controller.fetch;

  @override
  ExcludedRoutesDataChangedCallback get changeData => _changeData;

  @override
  void Function(VoidCallback onSaved) get submit => _controller.submit;

  @override
  void initState() {
    super.initState();
    final repositoryFactory = context.repositoryFactory;

    _controller = ExcludedRoutesController(
      repository: repositoryFactory.settingsRepository,
    );

    _controller.fetch();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<ExcludedRoutesController, ExcludedRoutesState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedExcludedRoutesScope(
      controller: this,
      state: state,
      child: widget.child,
    ),
  );

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _controller.removeListener(listener);

  void _changeData({
    List<String>? excludedRoutes,
    bool? hasInvalidRoutes,
  }) => _controller.dataChanged(
    excludedRoutes: excludedRoutes,
    hasInvalidRules: hasInvalidRoutes,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedExcludedRoutesScope extends InheritedModel<ExcludedRoutesAspect> {
  final ExcludedRoutesScopeController controller;

  final ExcludedRoutesState _state;

  const _InheritedExcludedRoutesScope({
    required this.controller,
    required this._state,
    required super.child,
  });

  List<String> get excludedRoutes => List<String>.unmodifiable(_state.excludedRoutes);

  List<String> get initialExcludedRoutes => List<String>.unmodifiable(_state.initialExcludedRoutes);

  bool get hasInvalidRoutes => _state.hasInvalidRoutes;

  PresentationException? get error => _state.error;

  bool get loading => _state.loading;

  bool get hasChanges => !listEquals(excludedRoutes, initialExcludedRoutes);

  bool get canSave => hasChanges && (!hasInvalidRoutes || excludedRoutes.isEmpty);

  @override
  bool updateShouldNotify(_InheritedExcludedRoutesScope oldWidget) => _state != oldWidget._state;

  static _InheritedExcludedRoutesScope controllerOf(
    BuildContext context, {
    bool listen = true,
    ExcludedRoutesAspect? aspect,
  }) => _scope(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedExcludedRoutesScope oldWidget,
    Set<ExcludedRoutesAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        ExcludedRoutesAspect.loading => loading != oldWidget.loading,
        ExcludedRoutesAspect.routes => !listEquals(
          _state.initialExcludedRoutes,
          oldWidget._state.initialExcludedRoutes,
        ),
        ExcludedRoutesAspect.data =>
          !listEquals(_state.excludedRoutes, oldWidget._state.excludedRoutes) ||
              !listEquals(_state.initialExcludedRoutes, oldWidget._state.initialExcludedRoutes) ||
              hasInvalidRoutes != oldWidget.hasInvalidRoutes ||
              error != oldWidget.error,
      };

      if (hasAnyChanges) return true;
    }

    return false;
  }

  static _InheritedExcludedRoutesScope? _scope(
    BuildContext context, {
    bool listen = true,
    ExcludedRoutesAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedExcludedRoutesScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedExcludedRoutesScope>()?.widget
            as _InheritedExcludedRoutesScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<ExcludedRoutesAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
