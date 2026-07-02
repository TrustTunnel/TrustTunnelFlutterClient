abstract class LaunchAndConnectionScopeController {
  abstract final bool isLaunchAtLoginEnabled;
  abstract final bool isLaunchAtLoginLoading;

  abstract final bool isOpenMainWindowOnLoginEnabled;
  abstract final bool isOpenMainWindowOnLoginLoading;

  abstract final bool isAutoConnectOnLaunchEnabled;
  abstract final bool isAutoConnectOnLaunchLoading;

  abstract final void Function(bool enabled) setLaunchAtLoginEnabled;
  abstract final void Function(bool enabled) setOpenMainWindowOnLoginEnabled;
  abstract final void Function(bool enabled) setAutoConnectOnLaunchEnabled;
}
