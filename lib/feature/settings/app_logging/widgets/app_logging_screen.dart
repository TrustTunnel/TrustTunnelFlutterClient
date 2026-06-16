import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/delete_app_logs_dialog.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/stripped_logging_dialog.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope_controller.dart';
import 'package:trusttunnel/widgets/common/custom_radio_list_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class AppLoggingScreen extends StatefulWidget {
  const AppLoggingScreen({super.key});

  @override
  State<AppLoggingScreen> createState() => _AppLoggingScreenState();
}

class _AppLoggingScreenState extends State<AppLoggingScreen> {
  late LoggingLevel _loggingLevel;
  late LoggingSecurityType _securityType;
  late AppLoggingScopeController _controller;
  late LogsManagerScopeController _logsManagerController;

  @override
  void initState() {
    super.initState();
    _logsManagerController = LogsManagerScope.controllerOf(
      context,
      listen: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = AppLoggingScope.controllerOf(context);
    _loggingLevel = _controller.loggingLevel;
    _securityType = _controller.securityType;
  }

  @override
  Widget build(BuildContext context) => ScaffoldWrapper(
    child: Scaffold(
      appBar: CustomAppBar(
        title: context.ln.appLogging,
        centerTitle: true,
        leadingIconType: AppBarLeadingIconType.back,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.ln.loggingLevel, style: context.textTheme.bodyLarge),
          ),
          CustomRadioListTile<LoggingLevel>(
            value: LoggingLevel.defaultLevel,
            groupValue: _loggingLevel,
            onChanged: _setLoggingLevel,
            title: context.ln.loggingLevelBasic,
            radioColor: context.colors.neutralBlack,
          ),
          CustomRadioListTile<LoggingLevel>(
            value: LoggingLevel.debug,
            groupValue: _loggingLevel,
            onChanged: _setLoggingLevel,
            title: context.ln.loggingLevelDetailed,
            subTitle: context.ln.loggingLevelDetailedDescription,
            radioColor: context.colors.neutralBlack,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.ln.sensitiveData, style: context.textTheme.bodyLarge),
          ),
          CustomRadioListTile<LoggingSecurityType>(
            value: LoggingSecurityType.stripped,
            groupValue: _securityType,
            onChanged: _setSecurityType,
            title: context.ln.sensitiveDataExcluded,
            subTitle: context.ln.sensitiveDataExcludedDescription,
            radioColor: context.colors.neutralBlack,
          ),
          CustomRadioListTile<LoggingSecurityType>(
            value: LoggingSecurityType.full,
            groupValue: _securityType,
            onChanged: _setSecurityType,
            title: context.ln.sensitiveDataIncluded,
            subTitle: context.ln.sensitiveDataIncludedDescription,
            radioColor: context.colors.neutralBlack,
          ),
          const Divider(),
          SizedBox(
            height: 64,
            child: Center(
              child: TextButton(
                onPressed: _controller.loading ? null : () => _deleteLogs(context),
                child: Text(
                  context.ln.deleteAppLogs,
                  style: context.textTheme.labelLarge?.copyWith(color: context.colors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _setLoggingLevel(LoggingLevel? value) {
    if (value != null) {
      _controller.updateLoggingLevel(level: value);
    }
  }

  Future<void> _setSecurityType(
    LoggingSecurityType? value,
  ) async {
    if (value == null || value == _securityType) {
      return;
    }

    final isUpdateToStripped = value == LoggingSecurityType.stripped;

    if (!isUpdateToStripped) {
      _controller.updateSecurityType(securityType: value);

      return;
    }

    final dialogActionResult = await showDialog<StrippedLoggingDialogAction>(
      context: context,
      builder: (_) => const StrippedLoggingDialog(),
    );

    if (dialogActionResult == null) {
      return;
    }

    switch (dialogActionResult) {
      case StrippedLoggingDialogAction.continueAnyway:
        _controller.updateSecurityType(securityType: value);
      case StrippedLoggingDialogAction.deleteLogs:
        _logsManagerController.deleteLogs(onDeleted: _showLogsDeletedSnackBar);
    }
  }

  Future<void> _deleteLogs(BuildContext context) async {
    final dialogActionResult = await showDialog<DeleteAppLogsDialogAction>(
      context: context,
      builder: (_) => const DeleteAppLogsDialog(),
    );

    if (!context.mounted || dialogActionResult != DeleteAppLogsDialogAction.deleteConfirmed) {
      return;
    }
    _logsManagerController.deleteLogs(onDeleted: _showLogsDeletedSnackBar);
  }

  void _showLogsDeletedSnackBar() {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.appLogsDeletedSnackbar);
  }
}
