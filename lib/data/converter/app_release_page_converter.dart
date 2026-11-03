import 'dart:convert';
import 'dart:typed_data';

import 'package:trusttunnel/common/constants/app_update_constants.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/converter/available_app_update_metadata_codec.dart';
import 'package:trusttunnel/data/model/app_release_page_data.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

final class AppReleasePageDecoder extends Converter<Uint8List, AppReleasePageData> {
  final AppVersion _installedVersion;
  final String _repositoryName;
  final bool _singleRelease;

  const AppReleasePageDecoder({
    required this._installedVersion,
    required this._repositoryName,
    required this._singleRelease,
  });

  @override
  AppReleasePageData convert(Uint8List body) {
    final Object? decoded = jsonDecode(utf8.decode(body));
    final List<dynamic> releases = _singleRelease ? [decoded] : decoded as List<dynamic>;
    AvailableAppUpdateData? newestUpdate;

    for (final dynamic release in releases) {
      final AvailableAppUpdateData? candidate = _parseAvailableUpdate(release as Map<String, dynamic>);
      final bool isNewer =
          candidate != null && (newestUpdate == null || candidate.version.compareTo(newestUpdate.version) > 0);

      if (isNewer) {
        newestUpdate = candidate;
      }
    }

    return AppReleasePageData(update: newestUpdate, count: releases.length);
  }

  AvailableAppUpdateData? _parseAvailableUpdate(Map<String, dynamic> release) {
    final bool invalidFlags = release['draft'] is! bool || release['prerelease'] is! bool;
    if (invalidFlags) {
      throw const FormatException('Invalid release flags');
    }

    final bool isUnstableRelease = release['draft'] == true || release['prerelease'] == true;
    if (isUnstableRelease) {
      return null;
    }

    final String tag = release['tag_name'] as String;
    if (!RegExp(r'^v[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(tag)) {
      return null;
    }

    final AppVersion version = AppVersion.parse(tag.substring(1));
    if (version.compareTo(_installedVersion) <= 0) {
      return null;
    }

    final List<Map<String, dynamic>> installerAssets = (release['assets'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((asset) => asset['name'] == AppUpdateConstants.installerBundleName)
        .toList();

    if (installerAssets.isEmpty) {
      return null;
    }

    if (installerAssets.length != 1) {
      throw const FormatException('Ambiguous Windows assets');
    }

    final Map<String, dynamic> asset = installerAssets.single;
    final String? digest = asset['digest'] as String?;
    final bool validAsset =
        asset['state'] == 'uploaded' && digest != null && RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest);

    if (!validAsset) {
      throw const FormatException('Invalid Windows asset state or digest');
    }

    return const AppUpdateMetadataValidator().convert(
      AvailableAppUpdateData(
        source: _repositoryName,
        releaseId: release['id'] as int,
        tag: tag,
        version: version,
        assetId: asset['id'] as int,
        name: asset['name'] as String,
        size: asset['size'] as int,
        sha256: digest.substring(7).toLowerCase(),
      ),
    );
  }
}
