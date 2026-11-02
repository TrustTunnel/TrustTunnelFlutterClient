import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';

@immutable
final class AvailableAppUpdateData {
  final String source;
  final int releaseId;
  final String tag;
  final AppVersion version;
  final int assetId;
  final String name;
  final int size;
  final String sha256;

  const AvailableAppUpdateData({
    required this.source,
    required this.releaseId,
    required this.tag,
    required this.version,
    required this.assetId,
    required this.name,
    required this.size,
    required this.sha256,
  });
}
