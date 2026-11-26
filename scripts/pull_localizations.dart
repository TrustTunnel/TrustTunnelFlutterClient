// Use `make ln-pull` to download approved ARB files from TwoSky.
// The script validates messages before it saves the files.
// `newRoutingProfileName` requires a name without a number in the `=0` branch.
// All other branches must include `{number}`.
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
  final sourcePlaceholders = <String, Set<String>>{};

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
      final sourceMessage = sourceArb[key];
      final message = arb[key];
      if (sourceMessage is! String || message is! String) {
        throw FormatException('$locale: Invalid message "$key". Check the source strings in Crowdin.');
      }

      final expectedPlaceholders = sourcePlaceholders.putIfAbsent(key, () {
        final metadata = switch (sourceArb['@$key']) {
          null => null,
          final Map<String, Object?> metadata => metadata['placeholders'],
          _ => throw FormatException('$baseLocale: Invalid metadata for source message "$key".'),
        };
        if (metadata != null) {
          if (metadata is! Map<String, Object?> || metadata.values.any((value) => value is! Map<String, Object?>)) {
            throw FormatException('$baseLocale: Invalid placeholder metadata for source message "$key".');
          }

          return metadata.keys.toSet();
        }

        try {
          return _MessageParser(sourceMessage).parse().placeholders.toSet();
        } on FormatException catch (exception) {
          throw FormatException('$baseLocale: Invalid source message "$key". ${exception.message}');
        }
      });

      try {
        _validateMessage(key, message, expectedPlaceholders);
      } on FormatException catch (exception) {
        throw FormatException('$locale: Invalid message "$key". ${exception.message}');
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

void _validateMessage(String key, String message, Set<String> expectedPlaceholders) {
  final parsed = _MessageParser(message).parse();
  final placeholders = parsed.placeholders.toSet();
  final missing = expectedPlaceholders.difference(placeholders);
  final unexpected = placeholders.difference(expectedPlaceholders);
  if (missing.isNotEmpty || unexpected.isNotEmpty) {
    throw FormatException('Missing placeholders: $missing. Unexpected placeholders: $unexpected.');
  }

  if (key == 'newRoutingProfileName') {
    _validateRoutingProfileName(parsed);
  }
}

void _validateRoutingProfileName(_Message message) {
  if (message case _Message(hasText: false, arguments: [(name: 'number', type: 'plural', :final branches)])) {
    if (branches.containsKey('zero')) {
      throw const FormatException('Use "=0" for the unnumbered name and remove the "zero" branch.');
    }

    final unnumbered = branches['=0'];
    if (unnumbered == null) {
      throw const FormatException('Missing the "=0" branch for "number".');
    }
    if (unnumbered.placeholders.contains('number')) {
      throw const FormatException('Remove {number} from the "=0" branch.');
    }
    if (!unnumbered.hasText) {
      throw const FormatException('Include a name in the "=0" branch.');
    }

    for (final MapEntry(key: selector, value: branch) in branches.entries) {
      if (selector != '=0' && !branch.arguments.any((argument) => argument.name == 'number' && argument.type == null)) {
        throw FormatException('Include {number} in the "$selector" branch.');
      }
    }

    return;
  }

  throw const FormatException('Expected a plural message for "number" with an unnumbered "=0" branch.');
}

typedef _Argument = ({String name, String? type, Map<String, _Message> branches});

final class _Message {
  final List<_Argument> arguments;
  final bool hasText;

  const _Message({required this.arguments, required this.hasText});

  Iterable<String> get placeholders sync* {
    for (final argument in arguments) {
      yield argument.name;
      for (final branch in argument.branches.values) {
        yield* branch.placeholders;
      }
    }
  }
}

// Parse the ICU constructs used by `intl_utils:generate`.
final class _MessageParser {
  static const _pluralSelectors = {'=0', '=1', '=2', 'zero', 'one', 'two', 'few', 'many', 'other'};
  static const _genderSelectors = {'female', 'male', 'other'};
  static final _identifier = RegExp(r'[a-zA-Z][a-zA-Z0-9_]*');
  static final _pluralSelector = RegExp(r'=[0-9]+|[a-zA-Z][a-zA-Z0-9_]*');
  static final _whitespace = RegExp(r'[\s\u0085]*');

  // The generator supports individual quoted braces in branch text.
  // A quote before a placeholder leaves the placeholder active.
  static final _literal = RegExp(r"''|'[{}]'|[^{}']+|'");

  final String _source;
  _MessageParser(this._source);

  int _offset = 0;

  _Message parse() => _readMessage(inBranch: false);

  _Message _readMessage({required bool inBranch}) {
    final arguments = <_Argument>[];
    bool hasText = false;
    while (_offset < _source.length) {
      if (_take('{')) {
        arguments.add(_readArgument());
        continue;
      }

      final literal = _literal.matchAsPrefix(_source, _offset);
      if (literal == null) {
        if (inBranch) {
          break;
        }
        _fail('Unexpected closing brace.');
      }

      final text = literal[0]!;
      if (inBranch && text.contains('<')) {
        _fail('A branch cannot contain "<".');
      }
      hasText = hasText || text.trim().isNotEmpty;
      _offset = literal.end;
    }

    return _Message(arguments: arguments, hasText: hasText);
  }

  _Argument _readArgument() {
    final name = _readToken(_identifier, 'an argument name');
    _skipWhitespace();
    if (_take('}')) {
      return (name: name, type: null, branches: const {});
    }

    if (!_take(',')) {
      _fail('Expected "}" or "," after "$name".');
    }
    final type = _readToken(_identifier, 'an argument type');
    final isPlural = type == 'plural';
    if (!isPlural && type != 'select') {
      _fail('Unsupported argument type "$type".');
    }

    _skipWhitespace();
    _expect(',');
    _skipWhitespace();

    final branches = <String, _Message>{};
    int lastBranchEnd = _offset;

    while (!_source.startsWith('}', _offset)) {
      final selector = _readToken(isPlural ? _pluralSelector : _identifier, 'a branch selector');
      if (isPlural && !_pluralSelectors.contains(selector)) {
        _fail('Unsupported plural selector "$selector".');
      }
      if (branches.containsKey(selector)) {
        _fail('Duplicate branch "$selector" for "$name".');
      }

      _skipWhitespace();
      _expect('{');
      branches[selector] = _readMessage(inBranch: true);
      _expect('}');
      lastBranchEnd = _offset;
      _skipWhitespace();
    }

    if (!branches.containsKey('other')) {
      _fail('Missing the "other" branch for "$name".');
    }

    // `intl_utils` allows trailing whitespace for plural and gender branches only.
    if (!isPlural && lastBranchEnd != _offset && !branches.keys.every(_genderSelectors.contains)) {
      _fail('Remove the space before the closing brace of the "$name" select argument.');
    }

    _expect('}');

    return (
      name: name,
      type: type,
      branches: branches,
    );
  }

  String _readToken(RegExp pattern, String expected) {
    _skipWhitespace();

    final match = pattern.matchAsPrefix(_source, _offset);
    if (match == null) {
      _fail('Expected $expected.');
    }
    _offset = match.end;

    return match[0]!;
  }

  void _skipWhitespace() {
    _offset = _whitespace.matchAsPrefix(_source, _offset)!.end;
  }

  bool _take(String token) {
    if (!_source.startsWith(token, _offset)) {
      return false;
    }
    _offset += token.length;

    return true;
  }

  void _expect(String token) {
    if (!_take(token)) {
      _fail('Expected "$token".');
    }
  }

  Never _fail(String message) => throw FormatException('Invalid ICU syntax at position ${_offset + 1}. $message');
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
