import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/router/page/route/popup_route.dart';
import 'package:trusttunnel/common/utils/common_utils.dart';
import 'package:trusttunnel/data/model/breakpoint.dart';
import 'package:trusttunnel/di/widgets/dependency_scope.dart';
import 'package:trusttunnel/di/model/dependency_factory.dart';
import 'package:trusttunnel/di/model/repository_factory.dart';
import 'package:trusttunnel/widgets/arb_parser/arb_parser.dart';
import 'package:trusttunnel/widgets/common/scaffold_messenger_provider.dart';
import 'package:trusttunnel/widgets/custom_snack_bar.dart';

extension ScreenTypeExtension on BuildContext {
  Breakpoint get breakpoint => CommonUtils.getBreakpointByWidth(MediaQuery.of(this).size.width);

  bool get isMobileBreakpoint => breakpoint == Breakpoint.XS;
}

extension MediaQueryExtension on BuildContext {
  double get scaleFactor => MediaQuery.of(this).textScaler.scale(1.0);
}

extension DependencyExtension on BuildContext {
  DependencyFactory get dependencyFactory => DependencyScope.getDependenciesFactory(this);

  RepositoryFactory get repositoryFactory => DependencyScope.getRepositoryFactory(this);
}

extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  CustomColors get colors => Theme.of(this).extension<CustomColors>()!;
}

extension SnackBarExtension on BuildContext {
  void showInfoSnackBar({
    required String message,
    bool showCloseIcon = true,
    SnackBarBehavior behavior = SnackBarBehavior.fixed,
  }) {
    var scaffoldMessenger = ScaffoldMessenger.of(this);

    if (scaffoldMessenger is ScaffoldMessengerProviderState) {
      scaffoldMessenger = scaffoldMessenger.value;
    }

    scaffoldMessenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        CustomSnackBar(
          content: ArbParser(
            data: message,
          ),
          behavior: behavior,
          showCloseIcon: showCloseIcon,
        ),
      );
  }
}

extension NavigatorExtension on BuildContext {
  void pop<T>({T? result}) => Navigator.of(this).pop(result);

  WidgetBuilder _getWidgetBuilder(BuildContext context, Widget widget) {
    final parentScaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    return (innerContext) => ScaffoldMessengerProvider(
      value: parentScaffoldMessenger ?? ScaffoldMessenger.of(innerContext),
      child: widget,
    );
  }

  Future<T?> push<T extends Object?>(Widget widget) => Navigator.of(this).push(
    MaterialPageRoute<T>(
      builder: (innerContext) => _getWidgetBuilder(this, widget).call(innerContext),
    ),
  );
}

extension RouterExtension on BuildContext {
  /// Pushes a new [PopUpRoute] and pops the current route off the navigator stack if [replace] is true.
  /// Before setting [replace] to true, ensure that the top route is a [PopUpRoute].
  Future<T?> pushPopUp<T extends Object?>(
    Widget widget, {
    bool fullScreen = true,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    bool replace = false,
    bool rootNavigator = true,
  }) {
    final actualNavigator = Navigator.of(this, rootNavigator: rootNavigator);
    final result = replace
        ? actualNavigator.pushReplacement<T, dynamic>(
            PopUpRoute(
              builder: (context) => widget,
              context: this,
              fullScreenDialog: fullScreen,
              transitionDuration: transitionDuration,
              reverseTransitionDuration: reverseTransitionDuration,
            ),
          )
        : actualNavigator.push<T>(
            PopUpRoute(
              builder: (context) => widget,
              context: this,
              fullScreenDialog: fullScreen,
              transitionDuration: transitionDuration,
              reverseTransitionDuration: reverseTransitionDuration,
            ),
          );

    return result;
  }
}
