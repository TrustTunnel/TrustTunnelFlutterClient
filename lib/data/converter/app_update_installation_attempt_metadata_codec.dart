import 'dart:convert';

import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/converter/available_app_update_metadata_codec.dart';
import 'package:trusttunnel/data/model/app_update_installation_attempt_data.dart';

final class AppUpdateOperationIdDecoder extends Converter<String, String> {
  const AppUpdateOperationIdDecoder();

  @override
  String convert(String input) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(input)) {
      throw const FormatException('Invalid operation ID');
    }

    return input;
  }
}

final class AppUpdateInstallationAttemptMetadataCodec
    extends Codec<AppUpdateInstallationAttemptData, Map<String, dynamic>> {
  const AppUpdateInstallationAttemptMetadataCodec();

  @override
  Converter<AppUpdateInstallationAttemptData, Map<String, dynamic>> get encoder => const _AttemptEncoder();

  @override
  Converter<Map<String, dynamic>, AppUpdateInstallationAttemptData> get decoder => const _AttemptDecoder();
}

final class _AttemptEncoder extends Converter<AppUpdateInstallationAttemptData, Map<String, dynamic>> {
  const _AttemptEncoder();

  @override
  Map<String, dynamic> convert(AppUpdateInstallationAttemptData input) => {
    'operation': input.operationId,
    'sourceVersion': input.sourceVersion.toString(),
    'update': const AvailableAppUpdateMetadataCodec().encode(input.update),
    'restoreServerId': input.restoreServerId,
  };
}

final class _AttemptDecoder extends Converter<Map<String, dynamic>, AppUpdateInstallationAttemptData> {
  const _AttemptDecoder();

  @override
  AppUpdateInstallationAttemptData convert(Map<String, dynamic> input) => AppUpdateInstallationAttemptData(
    operationId: const AppUpdateOperationIdDecoder().convert(input['operation'] as String),
    sourceVersion: AppVersion.parse(input['sourceVersion'] as String),
    update: const AvailableAppUpdateMetadataCodec().decode(input['update'] as Map<String, dynamic>),
    restoreServerId: input['restoreServerId'] as String?,
  );
}
