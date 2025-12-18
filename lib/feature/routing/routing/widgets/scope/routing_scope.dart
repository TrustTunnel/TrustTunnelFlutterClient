import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/feature/routing/routing/controller/routing_controller.dart';
import 'package:trusttunnel/feature/routing/routing/controller/routing_states.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_aspect.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';

/// {@template routing_scope_template}
/// Provides Routing controller to the widget tree
/// {@endtemplate}
class RoutingScope extends StatefulWidget {
  final Widget child;

  /// {@macro routing_scope_template}
  const RoutingScope({
    required this.child,
    super.key,
  });

  /// Get the controller from context
  static RoutingScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    RoutingScopeAspect? aspect,
  }) => _InheritedRoutingScope.controllerOf(context, listen: listen, aspect: aspect);

  @override
  State<RoutingScope> createState() => _RoutingScopeState();

  static RoutingController _rawControllerOf(BuildContext context) =>
      _InheritedRoutingScope.controllerOf(context, listen: false)._rawController;
}

class _RoutingScopeState extends State<RoutingScope> {
  late final RoutingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoutingController(
      repository: context.repositoryFactory.routingRepository,
    );
    _controller.fetchRoutingProfiles();
  }

  @override
  Widget build(BuildContext context) => RoutingScopeValue(
    controller: _controller,
    child: widget.child,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedRoutingScope extends InheritedModel<RoutingScopeAspect> implements RoutingScopeController {
  @override
  final void Function() fetchProfiles;

  @override
  final void Function({
    required int id,
    required String name,
    required VoidCallback onSaved,
  })
  changeName;

  @override
  final void Function(int routingProfileId, VoidCallback) deleteProfile;

  @override
  final void Function() pickProfileToChangeName;

  final RoutingController _rawController;

  const _InheritedRoutingScope({
    required this.fetchProfiles,
    required this.changeName,
    required this.deleteProfile,
    required this.pickProfileToChangeName,
    required this.error,
    required this.fieldErrors,
    required this.loading,
    required this.routingList,
    required RoutingController rawController,
    required super.child,
  }) : _rawController = rawController;

  // Controller API

  @override
  final List<RoutingProfile> routingList;

  @override
  final List<PresentationField> fieldErrors;

  @override
  final PresentationError? error;

  @override
  final bool loading;

  // Inherited plumbing

  @override
  bool updateShouldNotify(_InheritedRoutingScope oldWidget) =>
      error != oldWidget.error ||
      loading != oldWidget.loading ||
      !listEquals(routingList, oldWidget.routingList) ||
      !listEquals(fieldErrors, oldWidget.fieldErrors);

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedRoutingScope oldWidget,
    Set<RoutingScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        RoutingScopeAspect.loading => loading != oldWidget.loading,
        RoutingScopeAspect.profiles => !listEquals(routingList, oldWidget.routingList),
        RoutingScopeAspect.name => !listEquals(fieldErrors, oldWidget.fieldErrors),
      };

      if (hasAnyChanges) return true;
    }

    return false;
  }

  static _InheritedRoutingScope controllerOf(
    BuildContext context, {
    bool listen = true,
    RoutingScopeAspect? aspect,
  }) => _inheritFrom(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedRoutingScope? _inheritFrom(
    BuildContext context, {
    bool listen = true,
    RoutingScopeAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedRoutingScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedRoutingScope>()?.widget as _InheritedRoutingScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<RoutingScopeAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}

class RoutingScopeValue extends StatelessWidget {
  final Widget child;
  final RoutingController _controller;

  const RoutingScopeValue({
    required RoutingController controller,
    required this.child,
    super.key,
  }) : _controller = controller;

  RoutingScopeValue.fromContext({
    required BuildContext context,

    required this.child,
    super.key,
  }) : _controller = RoutingScope._rawControllerOf(context);

  @override
  Widget build(BuildContext context) => StateConsumer<RoutingController, RoutingState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedRoutingScope(
      fetchProfiles: _controller.fetchRoutingProfiles,
      changeName: _controller.editName,
      deleteProfile: _controller.deleteProfile,
      error: state.error,
      loading: state.loading,
      fieldErrors: [...state.fieldErrors],
      routingList: [...state.routingList],
      pickProfileToChangeName: () => _controller.dataChanged(
        fieldErrors: [],
      ),
      rawController: _controller,
      child: child,
    ),
  );
}
