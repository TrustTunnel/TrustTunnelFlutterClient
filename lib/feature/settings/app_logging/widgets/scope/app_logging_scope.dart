import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/logging/app_logger.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/sanitizer/log_sanitizer.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_state.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';

/// {@template routing_scope_template}
/// Provides Routing controller to the widget tree
/// {@endtemplate}
class AppLoggingScope extends StatefulWidget {
  final Widget child;

  /// {@macro routing_scope_template}
  const AppLoggingScope({
    required this.child,
    super.key,
  });

  /// Get the controller from context
  static AppLoggingScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    AppLoggingScopeAspect? aspect,
  }) => _InheritedAppLoggingScope.controllerOf(context, listen: listen, aspect: aspect);

  @override
  State<AppLoggingScope> createState() => _AppLoggingScopeState();
}

class _AppLoggingScopeState extends State<AppLoggingScope> {
  late final AppLoggingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppLoggingController(
      settingsRepository: context.repositoryFactory.loggingSettingsRepository,
    );
    _controller.fetch();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<AppLoggingController, AppLoggingState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedAppLoggingScope(
      loading: state.loading,
      loggingLevel: state.level,
      securityType: state.securityType,
      updateLoggingLevel: _updateLoggingLevel,
      updateSecurityType: _updateSecurityLevel,
      child: widget.child,
    ),
  );

  void _updateLoggingLevel({required LoggingLevel level}) => _controller.setLoggingLevel(
    level,
    onUpdated: (value) => _onLoggerUpdated(
      loggingLevel: value,
    ),
  );

  void _updateSecurityLevel({required LoggingSecurityType securityType}) => _controller.setSecurityType(
    securityType,
    onUpdated: (value) => _onLoggerUpdated(
      sanitizer: LogSanitizer(
        securityType: value,
      ),
    ),
  );

  void _onLoggerUpdated({
    LoggingLevel? loggingLevel,
    LogSanitizer? sanitizer,
  }) => (logger as AppLogger).updateSettings(
    loggingLevel: loggingLevel,
    sanitizer: sanitizer,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedAppLoggingScope extends InheritedModel<AppLoggingScopeAspect> implements AppLoggingScopeController {
  const _InheritedAppLoggingScope({
    required super.child,
    required this.loading,
    required this.loggingLevel,
    required this.securityType,
    required this.updateLoggingLevel,
    required this.updateSecurityType,
  });

  @override
  final bool loading;

  @override
  final LoggingLevel loggingLevel;

  @override
  final LoggingSecurityType securityType;

  @override
  final void Function({required LoggingLevel level}) updateLoggingLevel;

  @override
  final void Function({required LoggingSecurityType securityType}) updateSecurityType;

  @override
  bool updateShouldNotify(_InheritedAppLoggingScope oldWidget) =>
      loading != oldWidget.loading ||
      loggingLevel != oldWidget.loggingLevel ||
      securityType != oldWidget.securityType ||
      updateLoggingLevel != oldWidget.updateLoggingLevel ||
      updateSecurityType != oldWidget.updateSecurityType;

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedAppLoggingScope oldWidget,
    Set<AppLoggingScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        AppLoggingScopeAspect.loggingLevel => loggingLevel != oldWidget.loggingLevel,
        AppLoggingScopeAspect.securityType => securityType != oldWidget.securityType,
      };

      if (hasAnyChanges) return true;
    }

    return false;
  }

  static _InheritedAppLoggingScope controllerOf(
    BuildContext context, {
    bool listen = true,
    AppLoggingScopeAspect? aspect,
  }) => _inheritFrom(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedAppLoggingScope? _inheritFrom(
    BuildContext context, {
    bool listen = true,
    AppLoggingScopeAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedAppLoggingScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedAppLoggingScope>()?.widget
            as _InheritedAppLoggingScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<AppLoggingScopeAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
