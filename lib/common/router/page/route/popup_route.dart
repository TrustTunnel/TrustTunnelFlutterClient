import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/router/page/custom_page.dart';
import 'package:trusttunnel/common/utils/common_utils.dart';
import 'package:trusttunnel/data/model/breakpoint.dart';

class PopUpRoute<T> extends CustomPageRoute<T> {
  @override
  final bool maintainState;
  @override
  final bool opaque;
  final bool _fullScreenDialog;
  final BuildContext _context;
  final Duration? _transitionDuration;
  final Duration? _reverseTransitionDuration;
  PopUpRoute({
    required WidgetBuilder builder,
    required BuildContext context,
    bool fullScreenDialog = true,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    this.maintainState = true,
    this.opaque = false,
  }) : _builder = builder,
       _transitionDuration = transitionDuration,
       _reverseTransitionDuration = reverseTransitionDuration,
       _context = context,
       _fullScreenDialog = fullScreenDialog,
       super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop) {
    _initSub();
  }
  late final WidgetBuilder _builder;

  late final ValueNotifier<Breakpoint> _breakpointListenable;

  late bool _isFullScreen;

  ThemeData? _lastActualTheme;

  @override
  Color? get barrierColor => _isFullScreen ? null : _theme?.dialogTheme.barrierColor ?? Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => _transitionDuration ?? _defaultTransitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration ?? _defaultTransitionDuration;

  @override
  bool get fullscreenDialog => _fullScreenDialog;

  @override
  bool get popGestureEnabled => _isFullScreen;

  @override
  bool get popGestureInProgress => navigator?.userGestureInProgress ?? false;

  Duration get _defaultTransitionDuration =>
      _isFullScreen ? const Duration(milliseconds: 300) : const Duration(milliseconds: 200);

  ThemeData? get _theme {
    if (_context.mounted) {
      _lastActualTheme = _context.theme;
    }

    return _lastActualTheme;
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => (nextRoute is PopUpRoute && nextRoute.opaque);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    late final Widget transition;
    final size = MediaQuery.sizeOf(context);
    final actualBreakpoint = CommonUtils.getBreakpointByWidth(size.width);
    if (actualBreakpoint != _breakpointListenable.value) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _breakpointListenable.value = actualBreakpoint,
      );
    }

    if (_isFullScreen) {
      final PageTransitionsTheme theme = Theme.of(context).pageTransitionsTheme;
      transition = theme.buildTransitions<T>(this, context, animation, secondaryAnimation, child);
    } else {
      transition = FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    }

    return transition;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: _builder(context),
      );

  @override
  void dispose() {
    _breakpointListenable.removeListener(_breakPointListener);
    super.dispose();
  }

  void _initSub() {
    _breakpointListenable = ValueNotifier(_context.breakpoint);
    _performTransformationByBreakpoint(_breakpointListenable.value);
    _breakpointListenable.addListener(_breakPointListener);
  }

  void _breakPointListener() {
    _performTransformationByBreakpoint(_breakpointListenable.value);
    changedInternalState();
  }

  void _performTransformationByBreakpoint(Breakpoint breakpoint) {
    final isMobile = breakpoint == Breakpoint.XS;
    _isFullScreen = isMobile && _fullScreenDialog;
  }
}
