import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

abstract interface class AppVersionAndUpdatingScopeController implements Listenable {
  bool get updatesSupported;

  AppVersion? get version;

  AvailableAppUpdate? get availableUpdate;

  bool get initialLoadCompleted;

  bool get checkingForUpdates;

  bool get updating;

  bool get canCancelDownload;

  bool get isUpToDate;

  double get progress;

  AppUpdateException? get error;

  bool get showUpdateIndicator;

  String? get restoreServerId;

  String? get updatedVersion;

  void checkForUpdates({bool manual = true});

  void updateApplication();

  void retryUpdate();

  void cancelInstallerDownload();

  void resetManualUpdateCheckResult();

  void removeUpdateNotification();
}
