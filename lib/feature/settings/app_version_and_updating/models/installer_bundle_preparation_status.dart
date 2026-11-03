import 'package:flutter/foundation.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/downloaded_installer_bundle.dart';

/// Current status of installer preparation, including cache verification.
@immutable
sealed class InstallerBundlePreparationStatus {
  const InstallerBundlePreparationStatus();

  const factory InstallerBundlePreparationStatus.preparing() = InstallerBundlePreparingStatus;

  const factory InstallerBundlePreparationStatus.downloading({
    required int receivedBytes,
    required int totalBytes,
  }) = InstallerBundleDownloadingStatus;

  const factory InstallerBundlePreparationStatus.verifying() = InstallerBundleVerifyingStatus;

  const factory InstallerBundlePreparationStatus.ready(DownloadedInstallerBundle bundle) = InstallerBundleReadyStatus;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InstallerBundlePreparationStatus && runtimeType == other.runtimeType;

  @override
  String toString() => '$runtimeType';
}

final class InstallerBundlePreparingStatus extends InstallerBundlePreparationStatus {
  const InstallerBundlePreparingStatus();
}

final class InstallerBundleDownloadingStatus extends InstallerBundlePreparationStatus {
  final int receivedBytes;
  final int totalBytes;

  const InstallerBundleDownloadingStatus({
    required this.receivedBytes,
    required this.totalBytes,
  }) : assert(totalBytes > 0),
       assert(receivedBytes >= 0 && receivedBytes <= totalBytes);

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    receivedBytes,
    totalBytes,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallerBundleDownloadingStatus &&
          receivedBytes == other.receivedBytes &&
          totalBytes == other.totalBytes;

  @override
  String toString() => '$runtimeType(receivedBytes: $receivedBytes, totalBytes: $totalBytes)';
}

final class InstallerBundleVerifyingStatus extends InstallerBundlePreparationStatus {
  const InstallerBundleVerifyingStatus();
}

final class InstallerBundleReadyStatus extends InstallerBundlePreparationStatus {
  final DownloadedInstallerBundle bundle;

  const InstallerBundleReadyStatus(this.bundle);

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    bundle,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InstallerBundleReadyStatus && bundle == other.bundle;

  @override
  String toString() => '$runtimeType(bundle: $bundle)';
}
