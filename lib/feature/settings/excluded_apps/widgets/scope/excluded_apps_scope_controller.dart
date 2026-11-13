import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/installed_app.dart';

/// {@template excluded_apps_scope_controller}
/// Public contract of the per-app exclusions scope.
/// {@endtemplate}
abstract class ExcludedAppsScopeController implements Listenable {
  /// Currently selected package names (editable buffer).
  abstract final List<String> excludedApps;

  /// Persisted package names at fetch time.
  abstract final List<String> initialExcludedApps;

  /// Applications installed on the device.
  abstract final List<InstalledApp> installedApps;

  /// Whether the installed applications list is being loaded.
  abstract final bool appsLoading;

  abstract final bool hasChanges;
  abstract final bool canSave;
  abstract final bool loading;

  abstract final PresentationException? error;

  abstract final void Function() fetchExcludedApps;

  /// Replaces the editable buffer of excluded packages.
  abstract final void Function(List<String> excludedApps) changeExcludedApps;

  /// Checks or unchecks a single package.
  abstract final void Function(String packageName) toggleApp;

  abstract final void Function(VoidCallback onSaved) submit;
}
