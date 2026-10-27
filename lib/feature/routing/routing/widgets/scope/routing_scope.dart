import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
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
  }) => _InheritedRoutingScope.controllerOf(
    context,
    listen: listen,
    aspect: aspect,
  ).controller;

  @override
  State<RoutingScope> createState() => _RoutingScopeState();

  static RoutingController _rawControllerOf(BuildContext context) =>
      _InheritedRoutingScope.controllerOf(context, listen: false)._rawController;
}

class _RoutingScopeState extends State<RoutingScope> implements RoutingScopeController {
  late final RoutingController _controller;

  @override
  List<RoutingProfile> get routingList => [..._controller.state.routingList];

  @override
  List<PresentationField> get fieldErrors => [..._controller.state.fieldErrors];

  @override
  PresentationException? get error => _controller.state.error;

  @override
  bool get loading => _controller.state.loading;

  @override
  void Function() get fetchProfiles => _controller.fetchRoutingProfiles;

  @override
  void Function({
    required String id,
    required String name,
    required VoidCallback onSaved,
  })
  get changeName => _controller.editName;

  @override
  void Function(String routingProfileId, VoidCallback onDeleted) get deleteProfile => _controller.deleteProfile;

  @override
  void Function() get pickProfileToChangeName => _pickProfileToChangeName;

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
    controllerFacade: this,
    child: widget.child,
  );

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _controller.removeListener(listener);

  void _pickProfileToChangeName() => _controller.dataChanged(fieldErrors: []);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedRoutingScope extends InheritedModel<RoutingScopeAspect> {
  final RoutingScopeController controller;

  final RoutingController _rawController;

  const _InheritedRoutingScope({
    required this.controller,
    required this.error,
    required this.fieldErrors,
    required this.loading,
    required this.routingList,
    required this._rawController,
    required super.child,
  });

  final List<RoutingProfile> routingList;

  final List<PresentationField> fieldErrors;

  final PresentationException? error;

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
  final RoutingScopeController controllerFacade;

  const RoutingScopeValue({
    required this._controller,
    required this.controllerFacade,
    required this.child,
    super.key,
  });

  RoutingScopeValue.fromContext({
    required BuildContext context,

    required this.child,
    super.key,
  }) : _controller = RoutingScope._rawControllerOf(context),
       controllerFacade = RoutingScope.controllerOf(context, listen: false);

  @override
  Widget build(BuildContext context) => StateConsumer<RoutingController, RoutingState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedRoutingScope(
      controller: controllerFacade,
      error: state.error,
      loading: state.loading,
      fieldErrors: [...state.fieldErrors],
      routingList: [...state.routingList],
      rawController: _controller,
      child: child,
    ),
  );
}
