import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/value_data.dart';

@immutable
final class AppUpdatingOperationState {
  final int attemptId;
  final bool checkingForUpdates;
  final bool showManualCheckResult;
  final Timer? checkTimer;
  final Completer<void>? downloadCancellation;
  final String? installationOperationId;

  const AppUpdatingOperationState({
    this.attemptId = 0,
    this.checkingForUpdates = false,
    this.showManualCheckResult = false,
    this.checkTimer,
    this.downloadCancellation,
    this.installationOperationId,
  });

  AppUpdatingOperationState copyWith({
    int? attemptId,
    bool? checkingForUpdates,
    bool? showManualCheckResult,
    Timer? checkTimer,
    ValueData<Completer<void>>? downloadCancellation,
    String? installationOperationId,
  }) => AppUpdatingOperationState(
    attemptId: attemptId ?? this.attemptId,
    checkingForUpdates: checkingForUpdates ?? this.checkingForUpdates,
    showManualCheckResult: showManualCheckResult ?? this.showManualCheckResult,
    checkTimer: checkTimer ?? this.checkTimer,
    downloadCancellation: downloadCancellation == null ? this.downloadCancellation : downloadCancellation.value,
    installationOperationId: installationOperationId ?? this.installationOperationId,
  );
}
