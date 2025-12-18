import 'package:flutter/widgets.dart';
import 'package:trusttunnel/di/model/dependency_factory.dart';
import 'package:trusttunnel/di/model/repository_factory.dart';

class DependencyScope extends StatefulWidget {
  final DependencyFactory dependenciesFactory;
  final RepositoryFactory repositoryFactory;
  final Widget child;

  const DependencyScope({
    super.key,
    required this.dependenciesFactory,
    required this.repositoryFactory,
    required this.child,
  });

  @override
  State<DependencyScope> createState() => _DependencyScopeState();

  static DependencyFactory getDependenciesFactory(BuildContext context) => _scopeOf(context).dependenciesFactory;

  static RepositoryFactory getRepositoryFactory(BuildContext context) => _scopeOf(context).repositoryFactory;

  static DependencyScope _scopeOf(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<_InheritedDependencyScope>()!.widget
              as _InheritedDependencyScope)
          .state
          .widget;
}

class _DependencyScopeState extends State<DependencyScope> {
  @override
  Widget build(BuildContext context) => _InheritedDependencyScope(
    state: this,
    child: widget.child,
  );
}

class _InheritedDependencyScope extends InheritedWidget {
  final _DependencyScopeState state;

  const _InheritedDependencyScope({
    required super.child,
    required this.state,
  });

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
