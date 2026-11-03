import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';

@immutable
final class AvailableAppUpdate {
  final String source;
  final int releaseId;
  final String tag;
  final AppVersion version;
  final int assetId;
  final String name;
  final int size;
  final String sha256;

  const AvailableAppUpdate({
    required this.source,
    required this.releaseId,
    required this.tag,
    required this.version,
    required this.assetId,
    required this.name,
    required this.size,
    required this.sha256,
  });

  /// Identifies a cached installer by release and asset metadata before file verification.
  bool hasSameInstallerBundle(AvailableAppUpdate other) =>
      source == other.source &&
      releaseId == other.releaseId &&
      tag == other.tag &&
      assetId == other.assetId &&
      size == other.size &&
      sha256 == other.sha256;
}
