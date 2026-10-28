import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/constants/app_update_constants.dart';
import 'package:trusttunnel/common/models/app_version.dart';
import 'package:trusttunnel/data/datasources/releases_datasource.dart';
import 'package:trusttunnel/data/model/available_app_update_data.dart';

final class ReleasesDataSourceImpl implements ReleasesDataSource {
  final HttpClient Function(Duration timeout) _httpClientFactory;
  final Duration _timeout;
  final Uri _releasesUri;
  final String _repositoryName;

  ReleasesDataSourceImpl({
    required this._httpClientFactory,
    required this._timeout,
    required String baseUrl,
    required this._repositoryName,
  }) : _releasesUri = Uri.parse(baseUrl);

  @override
  Future<AvailableAppUpdateData?> findAvailableUpdate(AppVersion installedVersion) async {
    final HttpClient httpClient = _httpClientFactory(_timeout);

    try {
      return await _findAvailableUpdate(
        httpClient: httpClient,
        installedVersion: installedVersion,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  @override
  Stream<List<int>> openInstallerBundle({
    required int assetId,
    required Future<void> cancellation,
  }) async* {
    final HttpClient httpClient = _httpClientFactory(_timeout);
    bool active = true;
    unawaited(
      cancellation.then((_) {
        if (active) {
          httpClient.close(force: true);
        }
      }),
    );

    try {
      final Uri assetUri = _releasesUri.replace(path: '${_releasesUri.path}/assets/$assetId');
      final HttpClientRequest request = await httpClient.getUrl(assetUri).timeout(_timeout);

      request.headers.set(HttpHeaders.acceptHeader, 'application/octet-stream');
      request.headers.set(HttpHeaders.userAgentHeader, 'TrustTunnel');

      final HttpClientResponse response = await request.close().timeout(_timeout);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Asset HTTP ${response.statusCode}');
      }

      yield* response.timeout(_timeout);
    } finally {
      active = false;
      httpClient.close(force: true);
    }
  }

  Future<AvailableAppUpdateData?> _findAvailableUpdate({
    required HttpClient httpClient,
    required AppVersion installedVersion,
  }) async {
    final Object? latestRelease = await _readReleaseJson(
      httpClient: httpClient,
      uri: _releasesUri.replace(path: '${_releasesUri.path}/latest'),
      allowNotFound: true,
    );

    if (latestRelease != null) {
      final AvailableAppUpdateData? candidateUpdate = _parseAvailableUpdate(
        release: latestRelease as Map<String, dynamic>,
        installedVersion: installedVersion,
      );

      if (candidateUpdate != null) {
        return candidateUpdate;
      }
    }

    AvailableAppUpdateData? newestUpdate;
    for (int page = 1; ; page++) {
      final List<dynamic> releases = await _readReleaseJson(
        httpClient: httpClient,
        uri: _releasesUri.replace(queryParameters: {'per_page': '100', 'page': '$page'}),
      ) as List<dynamic>;

      if (releases.isEmpty) {
        break;
      }

      for (final dynamic release in releases) {
        final AvailableAppUpdateData? candidateUpdate = _parseAvailableUpdate(
          release: release as Map<String, dynamic>,
          installedVersion: installedVersion,
        );
        final bool isNewer =
            candidateUpdate != null &&
            (newestUpdate == null || candidateUpdate.version.compareTo(newestUpdate.version) > 0);

        if (isNewer) {
          newestUpdate = candidateUpdate;
        }
      }

      if (releases.length < 100) {
        break;
      }
    }

    return newestUpdate;
  }

  Future<Object?> _readReleaseJson({
    required HttpClient httpClient,
    required Uri uri,
    bool allowNotFound = false,
  }) async {
    final HttpClientRequest request = await httpClient.getUrl(uri).timeout(_timeout);

    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, AppConstants.appName);
    request.headers.set('X-GitHub-Api-Version', '2022-11-28');

    final HttpClientResponse response = await request.close().timeout(_timeout);

    final bool isMissingRelease = allowNotFound && response.statusCode == HttpStatus.notFound;
    if (isMissingRelease) {
      await response.drain<void>().timeout(_timeout);

      return null;
    }

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Release HTTP ${response.statusCode}', uri: uri);
    }

    final result = await utf8.decoder.bind(response).join().timeout(_timeout);

    return jsonDecode(result);
  }

  AvailableAppUpdateData? _parseAvailableUpdate({
    required Map<String, dynamic> release,
    required AppVersion installedVersion,
  }) {
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
    if (version.compareTo(installedVersion) <= 0) {
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

    return AvailableAppUpdateData.fromJson({
      'source': _repositoryName,
      'releaseId': release['id'],
      'tag': tag,
      'version': version.toString(),
      'assetId': asset['id'],
      'name': asset['name'],
      'size': asset['size'],
      'sha256': digest.substring(7).toLowerCase(),
    });
  }
}
