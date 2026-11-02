import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/exception/app_update_exception.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

@immutable
final class AppUpdateCheckState {
  final AppVersion? version;
  final bool initialLoadCompleted;
  final bool checkingForUpdates;
  final bool showManualCheckResult;
  final bool isUpToDate;
  final AvailableAppUpdate? availableUpdate;
  final AppUpdateCheckException? error;

  const AppUpdateCheckState({
    this.version,
    this.initialLoadCompleted = false,
    this.checkingForUpdates = false,
    this.showManualCheckResult = false,
    this.isUpToDate = false,
    this.availableUpdate,
    this.error,
  });

  bool get manualCheckInProgress => checkingForUpdates && showManualCheckResult;

  AppUpdateCheckState copyWith({
    AppVersion? version,
    bool? initialLoadCompleted,
    bool? checkingForUpdates,
    bool? showManualCheckResult,
    bool? isUpToDate,
    ValueData<AvailableAppUpdate>? availableUpdate,
    ValueData<AppUpdateCheckException>? error,
  }) => AppUpdateCheckState(
    version: version ?? this.version,
    initialLoadCompleted: initialLoadCompleted ?? this.initialLoadCompleted,
    checkingForUpdates: checkingForUpdates ?? this.checkingForUpdates,
    showManualCheckResult: showManualCheckResult ?? this.showManualCheckResult,
    isUpToDate: isUpToDate ?? this.isUpToDate,
    availableUpdate: availableUpdate == null ? this.availableUpdate : availableUpdate.value,
    error: error == null ? this.error : error.value,
  );
}
