import 'package:flutter/widgets.dart';

/// Base route descriptor used by [AppRoutes].
///
/// Equality, hashing, ordering, and string representation are based on [name].
@immutable
final class AppRoute {
  final String name;
  final RouteSettings settings;

  AppRoute(this.name) : settings = RouteSettings(name: name);

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AppRoute && other.name == name;

  @override
  String toString() => name;
}
