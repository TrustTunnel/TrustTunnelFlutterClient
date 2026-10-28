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

  factory AvailableAppUpdateData.fromJson(Map<String, dynamic> json) {
    final AvailableAppUpdateData update = AvailableAppUpdateData(
      source: json['source'] as String,
      releaseId: json['releaseId'] as int,
      tag: json['tag'] as String,
      version: AppVersion.parse(json['version'] as String),
      assetId: json['assetId'] as int,
      name: json['name'] as String,
      size: json['size'] as int,
      sha256: json['sha256'] as String,
    );
    final bool invalidMetadata =
        update.releaseId <= 0 ||
        update.assetId <= 0 ||
        update.size <= 0 ||
        update.tag != 'v${update.version}' ||
        update.name != 'TrustTunnel-windows.exe' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(update.sha256);

    if (invalidMetadata) {
      throw const FormatException('Invalid update metadata');
    }

    return update;
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    'releaseId': releaseId,
    'tag': tag,
    'version': version.toString(),
    'assetId': assetId,
    'name': name,
    'size': size,
    'sha256': sha256,
  };
}
