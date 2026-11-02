import 'dart:convert';

import 'package:trusttunnel/common/constants/app_update_constants.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

/// Validates metadata received from GitHub or read from the installer cache.
final class AppUpdateMetadataValidator extends Converter<AvailableAppUpdateData, AvailableAppUpdateData> {
  const AppUpdateMetadataValidator();

  @override
  AvailableAppUpdateData convert(AvailableAppUpdateData input) {
    final bool invalidMetadata =
        input.releaseId <= 0 ||
        input.assetId <= 0 ||
        input.size <= 0 ||
        input.tag != 'v${input.version}' ||
        input.name != AppUpdateConstants.installerBundleName ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(input.sha256);

    if (invalidMetadata) {
      throw const FormatException('Invalid update metadata');
    }

    return input;
  }
}

final class AvailableAppUpdateMetadataCodec extends Codec<AvailableAppUpdateData, Map<String, dynamic>> {
  const AvailableAppUpdateMetadataCodec();

  @override
  Converter<AvailableAppUpdateData, Map<String, dynamic>> get encoder => const _MetadataEncoder();

  @override
  Converter<Map<String, dynamic>, AvailableAppUpdateData> get decoder => const _MetadataDecoder();
}

final class _MetadataEncoder extends Converter<AvailableAppUpdateData, Map<String, dynamic>> {
  const _MetadataEncoder();

  @override
  Map<String, dynamic> convert(AvailableAppUpdateData input) => {
    'source': input.source,
    'releaseId': input.releaseId,
    'tag': input.tag,
    'version': input.version.toString(),
    'assetId': input.assetId,
    'name': input.name,
    'size': input.size,
    'sha256': input.sha256,
  };
}

final class _MetadataDecoder extends Converter<Map<String, dynamic>, AvailableAppUpdateData> {
  const _MetadataDecoder();

  @override
  AvailableAppUpdateData convert(Map<String, dynamic> input) => const AppUpdateMetadataValidator().convert(
    AvailableAppUpdateData(
      source: input['source'] as String,
      releaseId: input['releaseId'] as int,
      tag: input['tag'] as String,
      version: AppVersion.parse(input['version'] as String),
      assetId: input['assetId'] as int,
      name: input['name'] as String,
      size: input['size'] as int,
      sha256: input['sha256'] as String,
    ),
  );
}
