import 'package:flutter/foundation.dart';

@immutable
sealed class AppLoggingAction {
  const AppLoggingAction();

  const factory AppLoggingAction.settingsSaved() = AppLoggingSettingsSavedAction;

  const factory AppLoggingAction.logsDeleted() = AppLoggingLogsDeletedAction;
}

@immutable
final class AppLoggingSettingsSavedAction extends AppLoggingAction {
  const AppLoggingSettingsSavedAction();
}

@immutable
final class AppLoggingLogsDeletedAction extends AppLoggingAction {
  const AppLoggingLogsDeletedAction();
}
