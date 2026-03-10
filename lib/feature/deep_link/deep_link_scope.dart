import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/router/deeplink/deep_link_source.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/feature/deep_link/controller/deep_link_controller.dart';
import 'package:trusttunnel/feature/deep_link/controller/deep_link_state.dart';

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

  static _InheritedDeepLinkScope? maybeOf(BuildContext context, {bool listen = true}) => listen
      ? context.dependOnInheritedWidgetOfExactType<_InheritedDeepLinkScope>()
      : context.getElementForInheritedWidgetOfExactType<_InheritedDeepLinkScope>()?.widget as _InheritedDeepLinkScope?;

  static _InheritedDeepLinkScope of(BuildContext context, {bool listen = true}) =>
      maybeOf(context, listen: listen) ?? _notFoundInheritedWidgetOfExactType();

  static Never _notFoundInheritedWidgetOfExactType() => throw ArgumentError(
    'Out of scope, not found inherited widget '
        'a _InheritedDeepLinkScope of the exact type',
    'out_of_scope',
  );
}

/// State for widget DeepLinkScope.
class _DeepLinkScopeState extends State<DeepLinkScope> {
  late final DeepLinkSource _deepLinkSource;
  late final DeepLinkController _controller;

  @override
  void initState() {
    super.initState();
    _deepLinkSource = AppLinksSource(AppLinks());
    _controller = DeepLinkController(
      repository: context.repositoryFactory.deepLinkRepository,
    );
    _deepLinkSource.addListener(_onDeepLinkReceived);
    _deepLinkSource.getInitialLink().then((_) => _onDeepLinkReceived());
  }

  @override
  Widget build(BuildContext context) => StateConsumer<DeepLinkController, DeepLinkState>(
    controller: _controller,
    buildWhen: (previous, current) => previous.parsedData != current.parsedData,
    builder: (context, state, child) => _InheritedDeepLinkScope(
      deepLinkData: _controller.state.parsedData,
      child: child!,
    ),
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

class _InheritedDeepLinkScope extends InheritedWidget {
  const _InheritedDeepLinkScope({
    required this.deepLinkData,
    required super.child,
  });

  final ServerData? deepLinkData;

  @override
  bool updateShouldNotify(covariant _InheritedDeepLinkScope oldWidget) => deepLinkData != oldWidget.deepLinkData;
}
