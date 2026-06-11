import 'package:flutter/material.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/controller/app_logging_state.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/dialogs/delete_app_logs_dialog.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/dialogs/stripped_logging_dialog.dart';
import 'package:trusttunnel/widgets/common/custom_radio_list_tile.dart';
import 'package:trusttunnel/widgets/custom_app_bar.dart';
import 'package:trusttunnel/widgets/progress_wrapper.dart';
import 'package:trusttunnel/widgets/scaffold_wrapper.dart';

class AppLoggingScreen extends StatefulWidget {
  const AppLoggingScreen({super.key});

  @override
  State<AppLoggingScreen> createState() => _AppLoggingScreenState();
}

class _AppLoggingScreenState extends State<AppLoggingScreen> {
  late final AppLoggingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AppLoggingController(
      settingsRepository: context.repositoryFactory.loggingSettingsRepository,
      exportLogsRepository: context.repositoryFactory.exportLogsRepository,
      settingsListener: context.dependencyFactory.logger.updateSettings,
    )..fetch();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<AppLoggingController, AppLoggingState>(
    controller: _controller,
    listener: _onControllerStateChanged,
    builder: (context, state, _) => ScaffoldWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          title: context.ln.appLogging,
          centerTitle: true,
          leadingIconType: AppBarLeadingIconType.back,
        ),
        body: ProgressWrapper(
          isLoading: state.loading,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.ln.loggingLevel, style: context.textTheme.bodyLarge),
              ),
              CustomRadioListTile<LoggingLevel>(
                value: LoggingLevel.defaultLevel,
                groupValue: state.settings.level,
                onChanged: state.loading ? null : _setLoggingLevel,
                title: context.ln.loggingLevelBasic,
                radioColor: context.colors.neutralBlack,
              ),
              CustomRadioListTile<LoggingLevel>(
                value: LoggingLevel.debug,
                groupValue: state.settings.level,
                onChanged: state.loading ? null : _setLoggingLevel,
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
                groupValue: state.settings.securityType,
                onChanged: state.loading ? null : (value) => _changeSecurityType(context, value),
                title: context.ln.sensitiveDataExcluded,
                subTitle: context.ln.sensitiveDataExcludedDescription,
                radioColor: context.colors.neutralBlack,
              ),
              CustomRadioListTile<LoggingSecurityType>(
                value: LoggingSecurityType.full,
                groupValue: state.settings.securityType,
                onChanged: state.loading ? null : (value) => _changeSecurityType(context, value),
                title: context.ln.sensitiveDataIncluded,
                subTitle: context.ln.sensitiveDataIncludedDescription,
                radioColor: context.colors.neutralBlack,
              ),
              const Divider(),
              SizedBox(
                height: 64,
                child: Center(
                  child: TextButton(
                    onPressed: state.loading ? null : () => _deleteLogs(context),
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
      ),
    ),
  );

  void _onControllerStateChanged(
    BuildContext context,
    AppLoggingController controller,
    AppLoggingState previous,
    AppLoggingState current,
  ) {
    if (current is! AppLoggingErrorState) {
      return;
    }
    context.showInfoSnackBar(message: context.ln.unknownError);
  }

  void _setLoggingLevel(LoggingLevel? value) {
    if (value != null) _controller.setLoggingLevel(value);
  }

  Future<void> _changeSecurityType(
    BuildContext context,
    LoggingSecurityType? nextValue,
  ) async {
    if (nextValue == null || nextValue == _controller.state.settings.securityType) {
      return;
    }

    final isCurrentSecurityTypeFull = _controller.state.settings.securityType == LoggingSecurityType.full;
    final isNextSecurityTypeStripped = nextValue == LoggingSecurityType.stripped;
    if (isCurrentSecurityTypeFull && isNextSecurityTypeStripped) {
      final dialogActionResult = await showDialog<StrippedLoggingDialogAction>(
        context: context,
        builder: (_) => const StrippedLoggingDialog(),
      );
      if (!context.mounted || dialogActionResult == null) {
        return;
      }

      switch (dialogActionResult) {
        case StrippedLoggingDialogAction.continueAnyway:
          _controller.setSecurityType(nextValue);
        case StrippedLoggingDialogAction.deleteLogs:
          _controller.deleteLogsAndSetSecurityType(
            nextValue,
            onDeleted: _showLogsDeletedSnackBar,
          );
      }

      return;
    }

    if (!context.mounted) {
      return;
    }
    _controller.setSecurityType(nextValue);
  }

  Future<void> _deleteLogs(BuildContext context) async {
    final dialogActionResult = await showDialog<DeleteAppLogsDialogAction>(
      context: context,
      builder: (_) => const DeleteAppLogsDialog(),
    );

    if (!context.mounted || dialogActionResult != DeleteAppLogsDialogAction.deleteConfirmed) {
      return;
    }

    _controller.deleteLogs(onDeleted: _showLogsDeletedSnackBar);
  }

  void _showLogsDeletedSnackBar() {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.appLogsDeletedSnackbar);
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }
}
