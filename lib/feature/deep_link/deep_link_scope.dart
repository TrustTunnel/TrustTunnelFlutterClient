import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/router/deeplink/deep_link_source.dart';
import 'package:trusttunnel/feature/deep_link/controller/deep_link_controller.dart';

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
  late final DeepLinkSource _deepLinkSource;
  late final DeepLinkController _controller;

  @override
  void initState() {
    super.initState();
    _deepLinkSource = AppLinksSource(AppLinks());
    _controller = DeepLinkController(repository: context.repositoryFactory.serverRepository);
    _deepLinkSource.addListener(_onDeepLinkReceived);
    _deepLinkSource.getInitialLink().then((_) => _onDeepLinkReceived());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The configuration of InheritedWidgets has changed
    // Also called after initState but before build
  }

  @override
  void didUpdateWidget(DeepLinkScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget configuration changed
  }

  /* #endregion */

  @override
  Widget build(BuildContext context) => _InheritedDeepLinkScope(
    state: this,
    child: widget.child,
  );

  void _onDeepLinkReceived() {
    final link = _deepLinkSource.link;
    if (link != null) {
      _controller.onDeepLinkReceived(link.query);
    }
  }

  @override
  void dispose() {
    // Permanent removal of a tree stent
    super.dispose();
  }
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

  /// The state from the closest instance of this class
  /// that encloses the given context.
  /// For example: `DeepLinkScope.of(context)`.
  static _InheritedDeepLinkScope of(BuildContext context, {bool listen = true}) =>
      maybeOf(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  @override
  bool updateShouldNotify(covariant _InheritedDeepLinkScope oldWidget) => false;

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
    'Out of scope, not found inherited widget '
        'a _InheritedDeepLinkScope of the exact type',
    'out_of_scope',
  );
}
