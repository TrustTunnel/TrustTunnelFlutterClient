// Download approved ARB files from TwoSky with `make ln-pull`.
// Set TWOSKY_URI to use a different API base URL. Include /api/v1.

import 'dart:convert';
import 'dart:io';

const _defaultTwoSkyUri = 'https://twosky.int.agrd.dev/api/v1';
const _downloadTimeout = Duration(seconds: 60);

Future<void> main() async {
  final client = HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    await _pullLocalizations(client);
  } on Exception catch (exception) {
    stderr.writeln('Cannot import translations. $exception');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}

Future<void> _pullLocalizations(HttpClient client) async {
  final root = Platform.script.resolve('../');
  final config = File.fromUri(root.resolve('.twosky.json')).readAsStringSync();
  final (projectId, baseLocale, languages, localizations) = switch (jsonDecode(config) as Object?) {
    [
      {
        'project_id': final String projectId,
        'base_locale': final String baseLocale,
        'languages': final Map<String, Object?> languages,
        'custom_localizations_info': final Map<String, Object?> localizations,
      },
    ] =>
      (projectId, baseLocale, languages, localizations),
    _ => throw const FormatException('Invalid project in .twosky.json.'),
  };

  final sourceInfo = _findArbFile(localizations, baseLocale);
  final sourceUri = root.resolve(sourceInfo.localPath);
  final sourceArb = _decodeArb(File.fromUri(sourceUri).readAsStringSync(), baseLocale);

  final configuredUri = Platform.environment['TWOSKY_URI']?.trim() ?? '';
  final apiUri = Uri.parse(configuredUri.isEmpty ? _defaultTwoSkyUri : configuredUri);
  final apiPath = apiUri.path.replaceFirst(RegExp(r'/+$'), '');
  final translations = <String, String>{};

  for (final locale in languages.keys) {
    if (locale == baseLocale) {
      continue;
    }

    final target = _findArbFile(localizations, locale);
    final targetUri = root.resolve(target.localPath);
    if (targetUri == sourceUri) {
      throw const FormatException('The source ARB file cannot be a download target.');
    }

    final downloadUri = apiUri.replace(
      path: '$apiPath/download',
      queryParameters: {
        'project': projectId,
        'language': locale,
        'filename': target.crowdinPath,
      },
    );
    stdout.writeln('Download $locale from TwoSky');
    final content = await _downloadArb(client, downloadUri).timeout(_downloadTimeout);
    final arb = _decodeArb(content, locale);
    final messageKeys = arb.keys.where((key) => !key.startsWith('@') && key != '_locale');
    if (messageKeys.isEmpty) {
      throw FormatException('$locale: The ARB file has no messages.');
    }
    for (final key in messageKeys) {
      if (!sourceArb.containsKey(key) || arb[key] is! String) {
        throw FormatException('$locale: Invalid message "$key". Check the source strings in Crowdin.');
      }
    }

    // Use the Flutter locale from the file name. It can include the script code.
    final filename = targetUri.pathSegments.last;
    arb.remove('_locale');
    arb['@@locale'] = filename.substring('intl_'.length, filename.length - '.arb'.length);
    translations[target.localPath] = '${const JsonEncoder.withIndent('  ').convert(arb)}\n';
  }

  for (final entry in translations.entries) {
    final target = File.fromUri(root.resolve(entry.key));
    final tempDirectory = target.parent.createTempSync('.translations-');
    try {
      final staged = File.fromUri(tempDirectory.uri.resolve(target.uri.pathSegments.last));
      staged.writeAsStringSync(entry.value);
      staged.renameSync(target.path);
    } finally {
      tempDirectory.deleteSync(recursive: true);
    }
    stdout.writeln('Saved ${entry.key}');
  }
}

({String localPath, String crowdinPath}) _findArbFile(Map<String, Object?> localizations, String locale) =>
    switch (localizations[locale]) {
      [{'local_path': final String localPath, 'crowdin_path': final String crowdinPath}] => (
        localPath: localPath,
        crowdinPath: crowdinPath,
      ),
      _ => throw FormatException('$locale: Invalid ARB file entry in .twosky.json.'),
    };

Map<String, Object?> _decodeArb(String content, String locale) => switch (jsonDecode(content) as Object?) {
  final Map<String, Object?> arb => arb,
  _ => throw FormatException('$locale: Invalid ARB file.'),
};

Future<String> _downloadArb(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('TwoSky returned HTTP ${response.statusCode}.', uri: uri);
  }

  return utf8.decoder.bind(response).join();
}
