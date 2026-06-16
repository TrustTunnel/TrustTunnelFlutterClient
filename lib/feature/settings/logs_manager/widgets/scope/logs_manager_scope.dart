import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/settings/logs_manager/controller/logs_manager_controller.dart';
import 'package:trusttunnel/feature/settings/logs_manager/controller/logs_manager_state.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope_controller.dart';

/// {@template logs_manager_scope_template}
/// Provides LogsManager controller to the widget tree
/// {@endtemplate}
class LogsManagerScope extends StatefulWidget {
  final Widget child;

  /// {@macro logs_manager_scope_template}
  const LogsManagerScope({
    required this.child,
    super.key,
  });

  /// Get the controller from context
  static LogsManagerScopeController controllerOf(
    BuildContext context, {
    bool listen = true,
    LogsManagerScopeAspect? aspect,
  }) => _InheritedLogsManagerScope.controllerOf(context, listen: listen, aspect: aspect);

  @override
  State<LogsManagerScope> createState() => _LogsManagerScopeState();
}

class _LogsManagerScopeState extends State<LogsManagerScope> {
  late final LogsManagerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LogsManagerController(
      repository: context.repositoryFactory.exportLogsRepository,
    );
  }

  @override
  Widget build(BuildContext context) => StateConsumer<LogsManagerController, LogsManagerState>(
    controller: _controller,
    builder: (context, state, _) => _InheritedLogsManagerScope(
      loading: state.loading,
      archive: state.archive,
      exportLogs: _exportLogs,
      shareLogs: _shareLogs,
      deleteLogs: _deleteLogs,
      child: widget.child,
    ),
  );

  void _exportLogs({
    VoidCallback? onArchiveReady,
  }) => _controller.export(
    onArchiveReady: onArchiveReady,
  );

  void _shareLogs({
    required String subject,
    required String chooserTitle,
    VoidCallback? onDismissed,
    VoidCallback? onUnavailable,
  }) => _controller.share(
    subject: subject,
    chooserTitle: chooserTitle,
    onDismissed: onDismissed,
    onUnavailable: onUnavailable,
  );

  void _deleteLogs({
    VoidCallback? onDeleted,
  }) => _controller.deleteLogs(
    onDeleted: onDeleted,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _InheritedLogsManagerScope extends InheritedModel<LogsManagerScopeAspect> implements LogsManagerScopeController {
  const _InheritedLogsManagerScope({
    required super.child,
    required this.loading,
    required this.archive,
    required this.exportLogs,
    required this.shareLogs,
    required this.deleteLogs,
  });

  @override
  final bool loading;

  @override
  final ExportLogsArchive? archive;

  @override
  final void Function({
    VoidCallback? onArchiveReady,
  })
  exportLogs;

  @override
  final void Function({
    required String subject,
    required String chooserTitle,
    VoidCallback? onDismissed,
    VoidCallback? onUnavailable,
  })
  shareLogs;

  @override
  final void Function({
    VoidCallback? onDeleted,
  })
  deleteLogs;

  @override
  bool updateShouldNotify(_InheritedLogsManagerScope oldWidget) =>
      loading != oldWidget.loading ||
      archive != oldWidget.archive ||
      exportLogs != oldWidget.exportLogs ||
      shareLogs != oldWidget.shareLogs ||
      deleteLogs != oldWidget.deleteLogs;

  @override
  bool updateShouldNotifyDependent(
    covariant _InheritedLogsManagerScope oldWidget,
    Set<LogsManagerScopeAspect> dependencies,
  ) {
    if (dependencies.isEmpty) return updateShouldNotify(oldWidget);

    bool hasAnyChanges = false;

    for (final aspect in dependencies) {
      hasAnyChanges |= switch (aspect) {
        LogsManagerScopeAspect.loading => loading != oldWidget.loading,
        LogsManagerScopeAspect.archive => archive != oldWidget.archive,
      };

      if (hasAnyChanges) return true;
    }

    return false;
  }

  static _InheritedLogsManagerScope controllerOf(
    BuildContext context, {
    bool listen = true,
    LogsManagerScopeAspect? aspect,
  }) => _inheritFrom(context, listen: listen, aspect: aspect) ?? _notFoundInheritedWidgetOfExactType();

  static _InheritedLogsManagerScope? _inheritFrom(
    BuildContext context, {
    bool listen = true,
    LogsManagerScopeAspect? aspect,
  }) => (listen
      ? InheritedModel.inheritFrom<_InheritedLogsManagerScope>(
          context,
          aspect: aspect,
        )
      : context.getElementForInheritedWidgetOfExactType<_InheritedLogsManagerScope>()?.widget
            as _InheritedLogsManagerScope?);

  static Never _notFoundInheritedWidgetOfExactType<T extends InheritedModel<LogsManagerScopeAspect>>() =>
      throw ArgumentError(
        'Inherited widget out of scope and not found of $T exact type',
        'out_of_scope',
      );
}
