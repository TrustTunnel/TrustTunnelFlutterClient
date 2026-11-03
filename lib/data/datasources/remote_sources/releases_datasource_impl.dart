import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/common/network/network_client.dart';
import 'package:trusttunnel/common/utils/network_utils.dart';
import 'package:trusttunnel/data/converter/app_release_page_converter.dart';
import 'package:trusttunnel/data/datasources/releases_datasource.dart';
import 'package:trusttunnel/data/model/app_release_page_data.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

final class ReleasesDataSourceImpl implements ReleasesDataSource {
  final NetworkClient _releasesClient;
  final NetworkClient _downloadsClient;
  final Uri _releasesUri;
  final String _repositoryName;

  ReleasesDataSourceImpl({
    required this._releasesClient,
    required this._downloadsClient,
    required String baseUrl,
    required this._repositoryName,
  }) : _releasesUri = Uri.parse(baseUrl);

  @override
  Future<AvailableAppUpdateData?> findAvailableUpdate(AppVersion installedVersion) async {
    final AppReleasePageData latest = await _readReleasePage(
      uri: _releasesUri.replace(path: '${_releasesUri.path}/latest'),
      installedVersion: installedVersion,
      singleRelease: true,
      allowNotFound: true,
    );

    if (latest.update != null) {
      return latest.update;
    }

    AvailableAppUpdateData? newestUpdate;
    for (int page = 1; ; page++) {
      final AppReleasePageData releases = await _readReleasePage(
        uri: _releasesUri.replace(queryParameters: {'per_page': '100', 'page': '$page'}),
        installedVersion: installedVersion,
      );
      final AvailableAppUpdateData? candidate = releases.update;
      final bool isNewer =
          candidate != null && (newestUpdate == null || candidate.version.compareTo(newestUpdate.version) > 0);

      if (isNewer) {
        newestUpdate = candidate;
      }

      if (releases.count < 100) {
        break;
      }
    }

    return newestUpdate;
  }

  @override
  Stream<int> downloadInstallerBundle({
    required int assetId,
    required int expectedSize,
    required String destinationPath,
  }) => _downloadsClient.downloadFile(
    uri: _releasesUri.replace(path: '${_releasesUri.path}/assets/$assetId'),
    destinationPath: destinationPath,
    expectedSize: expectedSize,
  );

  Future<AppReleasePageData> _readReleasePage({
    required Uri uri,
    required AppVersion installedVersion,
    bool singleRelease = false,
    bool allowNotFound = false,
  }) async {
    final HttpClientResponse response = await _releasesClient.get(uri);
    final bool missingRelease = allowNotFound && response.statusCode == HttpStatus.notFound;

    if (missingRelease) {
      await NetworkUtils.discardResponse(response);

      return const AppReleasePageData(update: null, count: 0);
    }

    if (response.statusCode != HttpStatus.ok) {
      await NetworkUtils.discardResponse(response);

      throw HttpException('Release HTTP ${response.statusCode}', uri: uri);
    }

    final Uint8List body = await NetworkUtils.readResponseBytes(response, _releasesClient.configuration.timeout);

    return compute(
      AppReleasePageDecoder(
        installedVersion: installedVersion,
        repositoryName: _repositoryName,
        singleRelease: singleRelease,
      ).convert,
      body,
      debugLabel: 'decode-app-releases',
    );
  }
}
