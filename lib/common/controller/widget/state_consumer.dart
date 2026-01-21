import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../controller/state_controller.dart';

/// Callback invoked whenever the controller's state changes.
///
/// Provides access to the [BuildContext], the controller instance,
/// as well as the previous and current state values.
typedef StateConsumerListener<Controller extends StateController<State>, State extends Object> =
    void Function(BuildContext context, Controller controller, State previous, State current);

/// Condition that decides whether a rebuild should be triggered
/// for a given pair of previous and current state values.
typedef StateConsumerCondition<State extends Object> = bool Function(State previous, State current);

/// Function responsible for building UI in response to state updates.
typedef StateConsumerBuilder<State extends Object> = Widget Function(BuildContext context, State state, Widget? child);

/// {@template state_consumer}
/// Widget that listens to a [StateController] and optionally rebuilds
/// when the controller's state changes.
///
/// It combines a [listener] for side effects and a [builder] for rendering
/// the current state.
/// {@endtemplate}
class StateConsumer<C extends StateController<S>, S extends Object> extends StatefulWidget {
  /// The controller responsible for processing the logic.
  final C controller;

  /// Callback invoked on every state change.
  final StateConsumerListener<C, S>? listener;

  /// Predicate that determines whether the widget should rebuild
  /// for a given state transition.
  final StateConsumerCondition<S>? buildWhen;

  /// Builder invoked to render the widget for the current state.
  final StateConsumerBuilder<S>? builder;

  /// The child widget which will be passed to the [builder].
  final Widget? child;

  /// {@macro state_consumer}
  const StateConsumer({
    required this.controller,
    this.listener,
    this.buildWhen,
    this.builder,
    this.child,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _StateConsumerState<C, S>();
}

class _StateConsumerState<C extends StateController<S>, S extends Object> extends State<StateConsumer<C, S>> {
  late C _controller;
  late S _previousState;

  @override
  void didChangeDependencies() {
    _controller = widget.controller;
    _previousState = _controller.state;
    _subscribe();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant StateConsumer<C, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller;
    final newController = widget.controller;

    if (identical(oldController, newController) || oldController == newController) return;

    _unsubscribe();
    _controller = newController;
    _previousState = _controller.state;
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return widget.builder!(context, _controller.state, widget.child);
    }

    return widget.child ?? const SizedBox.shrink();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) => super.debugFillProperties(
    properties
      ..add(DiagnosticsProperty<StateController<S>>('stateController', _controller))
      ..add(DiagnosticsProperty<S>('state', _controller.state))
      ..add(DiagnosticsProperty<bool>('isProcessing', _controller.isProcessing)),
  );

  void _subscribe() => _controller.addListener(_handleStateChanged);

  void _unsubscribe() {
    if (_controller.isDisposed) return;
    _controller.removeListener(_handleStateChanged);
  }

  void _handleStateChanged() {
    final oldState = _previousState;
    final newState = _controller.state;
    if (!mounted || identical(oldState, newState)) return;

    _previousState = newState;

    widget.listener?.call(context, _controller, oldState, newState);
    final shouldRebuild = widget.buildWhen?.call(oldState, newState) ?? true;
    if (!shouldRebuild) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    switch (phase) {
      case SchedulerPhase.idle:
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.postFrameCallbacks:
        setState(() {});
      case SchedulerPhase.persistentCallbacks:
      case SchedulerPhase.midFrameMicrotasks:
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
