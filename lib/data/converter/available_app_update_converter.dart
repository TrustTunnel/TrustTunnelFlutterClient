import 'dart:convert';

import 'package:trusttunnel/data/model/available_app_update_data.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/models/available_app_update.dart';

final class AvailableAppUpdateEncoder extends Converter<AvailableAppUpdate, AvailableAppUpdateData> {
  const AvailableAppUpdateEncoder();

  @override
  AvailableAppUpdateData convert(AvailableAppUpdate value) => AvailableAppUpdateData(
    source: value.source,
    releaseId: value.releaseId,
    tag: value.tag,
    version: value.version,
    assetId: value.assetId,
    name: value.name,
    size: value.size,
    sha256: value.sha256,
  );
}

final class AvailableAppUpdateDecoder extends Converter<AvailableAppUpdateData, AvailableAppUpdate> {
  const AvailableAppUpdateDecoder();

  @override
  AvailableAppUpdate convert(AvailableAppUpdateData value) => AvailableAppUpdate(
    source: value.source,
    releaseId: value.releaseId,
    tag: value.tag,
    version: value.version,
    assetId: value.assetId,
    name: value.name,
    size: value.size,
    sha256: value.sha256,
  );
}
