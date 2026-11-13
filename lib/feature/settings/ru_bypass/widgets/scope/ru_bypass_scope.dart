import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/controller/ru_bypass_controller.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/controller/ru_bypass_states.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/widgets/scope/ru_bypass_aspect.dart';
import 'package:trusttunnel/feature/settings/ru_bypass/widgets/scope/ru_bypass_scope_controller.dart';

/// {@template ru_bypass_scope}
/// Application-level scope holding the Runet bypass state.
/// {@endtemplate}
class RuBypassScope extends StatefulWidget {
  final Widget child;

  const RuBypassScope({
    required this.child,
    super.key,
  });

  static RuBypassScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    RuBypassAspect? aspect,
  }) => _InheritedRuBypassScope.controllerOf(
    context,
    listen: listen,
    aspect: aspect,
  ).controller;

  /// Returns the scope controller if a RuBypassScope is above in the tree,
  /// otherwise `null`.
  static RuBypassScopeController? maybeControllerOf(
    BuildContext context, {
    bool listen = false,
  }) {
    final element = context.getElementForInheritedWidgetOfExactType<_InheritedRuBypassScope>();

    return element == null ? null : (element.widget as _InheritedRuBypassScope).controller;
  }

  @override
  State<RuBypassScope> createState() => _RuBypassScopeState();
}

class _RuBypassScopeState extends State<RuBypassScope> implements RuBypassScopeController {
  late final RuBypassController _controller;

  @override
  bool get enabled => _controller.state.enabled;

  @override
  DateTime? get lastUpdateDate => _controller.state.lastUpdateDate;

  @override
  int get cidrCount => _controller.state.cidrCount;

  @override
  bool get loading => _controller.state.loading;

  @override
  PresentationException? get error => _controller.state.error;

  @override
  List<String> get cidrList => List<String>.unmodifiable(_controller.cidrList);

  @override
  void Function() get fetchRuBypass => _controller.fetch;

  @override
  void Function(bool enabled) get changeEnabled => _controller.setEnabled;

  @override
  void Function(void Function(int cidrCount) onSuccess) get updateLists =>
      (onSuccess) => _controller.updateLists(onSuccess: onSuccess);

  @override
  void initState() {
    super.initState();
    final repositoryFactory = context.repositoryFactory;

    _controller = RuBypassController(repositoryFactory.ruBypassRepository);

    _controller.fetch();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<RuBypassController, RuBypassState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedRuBypassScope(
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

class _InheritedRuBypassScope extends InheritedModel<RuBypassAspect> {
  final RuBypassScopeController controller;

  final RuBypassState state;

  const _InheritedRuBypassScope({
    required this.controller,
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedRuBypassScope oldWidget) => state != oldWidget.state;

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedRuBypassScope oldWidget,
    Set<RuBypassAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    for (final aspect in dependencies) {
      switch (aspect) {
        case RuBypassAspect.loading:
          if (state.loading != oldWidget.state.loading) return true;
        case RuBypassAspect.data:
          if (state != oldWidget.state) return true;
      }
    }

    return false;
  }

  static _InheritedRuBypassScope controllerOf(
    BuildContext context, {
    bool listen = true,
    RuBypassAspect? aspect,
  }) => _scope(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedRuBypassScope? _scope(
    BuildContext context, {
    bool listen = true,
    RuBypassAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedRuBypassScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedRuBypassScope>()?.widget
            as _InheritedRuBypassScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<RuBypassAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
