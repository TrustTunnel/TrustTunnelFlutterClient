import 'package:flutter/widgets.dart';

/// {@template deep_link_scope}
/// DeepLinkScope widget.
/// {@endtemplate}
class DeepLinkScope extends StatefulWidget {
  const DeepLinkScope({
    required this.child,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  State<DeepLinkScope> createState() => _DeepLinkScopeState();
}

/// State for widget DeepLinkScope.
class _DeepLinkScopeState extends State<DeepLinkScope> {
  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();
    // Initial state initialization
  }

  @override
  void didUpdateWidget(DeepLinkScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget configuration changed
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The configuration of InheritedWidgets has changed
    // Also called after initState but before build
  }

  @override
  void dispose() {
    // Permanent removal of a tree stent
    super.dispose();
  }

  /* #endregion */

  @override
  Widget build(BuildContext context) => _InheritedDeepLinkScope(
        state: this,
        child: widget.child,
      );
}

/// Inherited widget for quick access in the element tree.
class _InheritedDeepLinkScope extends InheritedWidget {
  const _InheritedDeepLinkScope({
    required this.state,
    required super.child,
  });

  final _DeepLinkScopeState state;

  /// The state from the closest instance of this class
  /// that encloses the given context, if any.
  /// For example: `DeepLinkScope.maybeOf(context)`.
  static _InheritedDeepLinkScope? maybeOf(BuildContext context, {bool listen = true}) => listen
    ? context.dependOnInheritedWidgetOfExactType<_InheritedDeepLinkScope>()
    : context.getElementForInheritedWidgetOfExactType<_InheritedDeepLinkScope>()?.widget as _InheritedDeepLinkScope?;

  static Never _notFoundInheritedWidgetOfExactType() =>
    throw ArgumentError(
      'Out of scope, not found inherited widget '
          'a _InheritedDeepLinkScope of the exact type',
      'out_of_scope',
    );

  /// The state from the closest instance of this class
  /// that encloses the given context.
  /// For example: `DeepLinkScope.of(context)`.
  static _InheritedDeepLinkScope of(BuildContext context, {bool listen = true}) =>
    maybeOf(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotify(covariant _InheritedDeepLinkScope oldWidget) => false;
}
