enum AppUpdateInstallationStatus {
  success('success'),
  failed('failed'),
  rolledBack('rolled_back'),
  rollbackFailed('rollback_failed'),
  launchFailed('launch_failed'),
  rollbackLaunchFailed('rollback_launch_failed'),
  autostartFailed('autostart_failed');

  final String value;

  const AppUpdateInstallationStatus(this.value);
}
