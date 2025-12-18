import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
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
  }) => _InheritedExcludedRoutesScope.controllerOf(context, listen: listen, aspect: aspect);

  @override
  State<ExcludedRoutesScope> createState() => _ExcludedRoutesScopeState();
}

class _ExcludedRoutesScopeState extends State<ExcludedRoutesScope> {
  late final ExcludedRoutesController _controller;

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
      state: state,
      changeData:
          ({
            List<String>? excludedRoutes,
            bool? hasInvalidRoutes,
          }) => _controller.dataChanged(
            excludedRoutes: excludedRoutes,
            hasInvalidRules: hasInvalidRoutes,
          ),
      fetchExcludedRoutes: _controller.fetch,
      submit: _controller.submit,
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedExcludedRoutesScope extends InheritedModel<ExcludedRoutesAspect>
    implements ExcludedRoutesScopeController {
  final ExcludedRoutesState _state;

  const _InheritedExcludedRoutesScope({
    required ExcludedRoutesState state,
    required this.changeData,
    required this.fetchExcludedRoutes,
    required this.submit,
    required super.child,
  }) : _state = state;

  @override
  final ExcludedRoutesDataChangedCallback changeData;

  @override
  final void Function() fetchExcludedRoutes;

  @override
  final void Function(VoidCallback onSaved) submit;

  @override
  List<String> get excludedRoutes => List<String>.unmodifiable(_state.excludedRoutes);

  @override
  List<String> get initialExcludedRoutes => List<String>.unmodifiable(_state.initialExcludedRoutes);

  @override
  bool get hasInvalidRoutes => _state.hasInvalidRoutes;

  @override
  PresentationError? get error => _state.error;

  @override
  bool get loading => _state.loading;

  @override
  bool get hasChanges => !listEquals(excludedRoutes, initialExcludedRoutes);

  @override
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
