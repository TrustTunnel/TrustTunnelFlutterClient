import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/data/datasources/ru_bypass_datasource.dart';
import 'package:trusttunnel/data/datasources/ru_bypass_update_result.dart';

/// {@template ru_bypass_data_source_impl}
/// File- and preferences-backed implementation of [RuBypassDataSource].
///
/// The Russian IP ranges list is downloaded as JSON from the RIPE NCC
/// country-resource-list API and stored as a plain text file (one CIDR per
/// line) in the application documents directory.
/// {@endtemplate}
class RuBypassDataSourceImpl implements RuBypassDataSource {
  static const _enabledKey = 'ru_bypass_enabled';

  /// Storage format generation; bumping it makes stale lists downloaded by
  /// previous versions (e.g. from a different source) ignored.
  static const _storageGeneration = 'v2';
  static const _lastUpdateKey = 'ru_bypass_last_update_$_storageGeneration';
  static const _cidrFileName = 'runet_cidr_$_storageGeneration.lst';

  final SharedPreferences preferences;

  /// Source of the CIDR list.
  final Uri cidrListUrl;

  /// Download timeout.
  final Duration timeout;

  /// {@macro ru_bypass_data_source_impl}
  RuBypassDataSourceImpl({
    required this.preferences,
    required this.cidrListUrl,
    this.timeout = const Duration(seconds: 30),
  });

  static final RegExp _cidrRegExp = RegExp(r'^[0-9a-fA-F:.]+/\d{1,3}$');
  static final RegExp _rangeRegExp = RegExp(r'^([0-9a-fA-F:.]+)-([0-9a-fA-F:.]+)$');

  /// Minimum number of entries expected from the RU country list; guards
  /// against a broken or truncated response wiping the stored list.
  static const _minExpectedEntries = 1000;

  @override
  Future<bool> isEnabled() async => preferences.getBool(_enabledKey) ?? false;

  @override
  Future<void> setEnabled(bool enabled) => preferences.setBool(_enabledKey, enabled);

  @override
  Future<List<String>> getCidrList() async {
    final file = await _cidrFile();
    if (!await file.exists()) {
      return const [];
    }

    final content = await file.readAsString();

    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList(growable: false);
  }

  @override
  Future<DateTime?> getLastUpdateDate() async {
    final raw = preferences.getInt(_lastUpdateKey);

    return raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  @override
  Future<bool> hasCidrList() async => preferences.containsKey(_lastUpdateKey);

  @override
  Future<RuBypassUpdateResult> updateCidrList() async {
    final cidrs = await _downloadCidrList();
    final file = await _cidrFile();
    await file.writeAsString(cidrs.join('\n'));

    final updatedAt = DateTime.now();
    await preferences.setInt(_lastUpdateKey, updatedAt.millisecondsSinceEpoch);

    return RuBypassUpdateResult(cidrCount: cidrs.length, updatedAt: updatedAt);
  }

  Future<File> _cidrFile() async {
    final dir = await getApplicationDocumentsDirectory();

    return File('${dir.path}${Platform.pathSeparator}$_cidrFileName');
  }

  /// Downloads the list and parses it into a deduplicated list of CIDRs.
  Future<List<String>> _downloadCidrList() async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(cidrListUrl).timeout(timeout);
      final response = await request.close().timeout(timeout);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download the RU CIDR list: HTTP ${response.statusCode}',
          uri: cidrListUrl,
        );
      }

      final raw = await response.transform(utf8.decoder).join();
      final parsed = _aggregate(_parseCountryResourceList(raw));

      if (parsed.length < _minExpectedEntries) {
        throw const FormatException('Downloaded RU CIDR list does not look valid');
      }

      return parsed;
    } finally {
      client.close(force: true);
    }
  }

  /// Parses the `country-resource-list` JSON into a deduplicated CIDR list.
  ///
  /// Entries come either as CIDRs (`2.56.24.0/23`) or as dash-separated
  /// ranges (`31.135.244.0-31.135.251.255`); ranges are expanded into the
  /// covering CIDRs.
  List<String> _parseCountryResourceList(String raw) {
    final body = jsonDecode(raw) as Map<String, Object?>;
    final data = body['data'] as Map<String, Object?>;
    final resources = data['resources'] as Map<String, Object?>;

    final entries = <String>{
      ..._asStringList(resources['ipv4']),
      ..._asStringList(resources['ipv6']),
    };

    final cidrs = <String>{};
    for (final entry in entries) {
      final rangeMatch = _rangeRegExp.firstMatch(entry);
      if (rangeMatch != null) {
        cidrs.addAll(_expandRange(rangeMatch[1]!, rangeMatch[2]!));
      } else if (_cidrRegExp.hasMatch(entry)) {
        cidrs.add(entry);
      }
    }

    return cidrs.toList(growable: false);
  }

  static List<String> _asStringList(Object? raw) =>
      raw is List ? raw.whereType<String>().toSet().toList(growable: false) : const <String>[];

  /// Merges overlapping/adjacent CIDRs per address family into minimal ranges,
  /// shrinking the list that ends up in the VPN configuration.
  List<String> _aggregate(List<String> cidrs) {
    final intervals = <(BigInt, BigInt, int)>[];
    for (final cidr in cidrs) {
      final parts = cidr.split('/');
      if (parts.length != 2) {
        continue;
      }
      final version = parts[0].contains(':') ? 6 : 4;
      final bits = version == 6 ? 128 : 32;
      final prefix = int.tryParse(parts[1]);
      final start = _ipToBigInt(parts[0]);
      if (prefix == null || prefix < 0 || prefix > bits || start == null) {
        continue;
      }
      final hostBits = bits - prefix;
      final end = start + (BigInt.one << hostBits) - BigInt.one;
      intervals.add((start, end, version));
    }

    final result = <String>[];
    for (final version in const [4, 6]) {
      final family = intervals.where((i) => i.$3 == version).toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));

      BigInt? mergeStart;
      BigInt mergeEnd = BigInt.zero;
      for (final (start, end, _) in family) {
        if (mergeStart == null) {
          mergeStart = start;
          mergeEnd = end;
          continue;
        }
        if (start <= mergeEnd + BigInt.one) {
          if (end > mergeEnd) {
            mergeEnd = end;
          }
          continue;
        }
        result.addAll(_expandRange(_bigIntToIp(mergeStart, version), _bigIntToIp(mergeEnd, version)));
        mergeStart = start;
        mergeEnd = end;
      }
      if (mergeStart != null) {
        result.addAll(_expandRange(_bigIntToIp(mergeStart, version), _bigIntToIp(mergeEnd, version)));
      }
    }

    return result;
  }

  /// Expands the `first-last` range into the covering CIDRs.
  static List<String> _expandRange(String first, String last) {
    final start = _ipToBigInt(first);
    final end = _ipToBigInt(last);
    if (start == null || end == null || start > end) {
      return const <String>[];
    }

    final version = first.contains(':') ? 6 : 4;
    final bits = version == 6 ? 128 : 32;
    final result = <String>[];
    var current = start;
    while (current <= end) {
      var blockSizeBits = 0;
      while (blockSizeBits < bits) {
        final candidate = BigInt.one << (blockSizeBits + 1);
        if (current % candidate != BigInt.zero || current + candidate - BigInt.one > end) {
          break;
        }
        blockSizeBits++;
      }
      result.add('${_bigIntToIp(current, version)}/${bits - blockSizeBits}');
      current += BigInt.one << blockSizeBits;
    }

    return result;
  }

  static BigInt? _ipToBigInt(String address) {
    final addr = InternetAddress.tryParse(address);
    if (addr == null) {
      return null;
    }

    var value = BigInt.zero;
    for (final byte in addr.rawAddress) {
      value = (value << 8) | BigInt.from(byte);
    }

    return value;
  }

  static String _bigIntToIp(BigInt value, int version) {
    if (version == 4) {
      var rest = value;
      final octets = List<int>.filled(4, 0);
      for (var i = 3; i >= 0; i--) {
        octets[i] = (rest & BigInt.from(0xff)).toInt();
        rest >>= 8;
      }

      return octets.join('.');
    }

    var rest = value;
    final groups = List<int>.filled(8, 0);
    for (var i = 7; i >= 0; i--) {
      groups[i] = (rest & BigInt.from(0xffff)).toInt();
      rest >>= 16;
    }

    // Compress the longest all-zero group run (>= 2 groups) into '::'.
    var bestStart = -1;
    var bestLength = 0;
    var currentStart = -1;
    var currentLength = 0;
    for (var i = 0; i < groups.length; i++) {
      if (groups[i] == 0) {
        if (currentStart < 0) {
          currentStart = i;
          currentLength = 1;
        } else {
          currentLength++;
        }
        if (currentLength > bestLength) {
          bestStart = currentStart;
          bestLength = currentLength;
        }
      } else {
        currentStart = -1;
        currentLength = 0;
      }
    }

    if (bestLength < 2) {
      return groups.map((group) => group.toRadixString(16).padLeft(4, '0')).join(':');
    }

    final head = groups.sublist(0, bestStart).map((g) => g.toRadixString(16)).join(':');
    final tail = groups.sublist(bestStart + bestLength).map((g) => g.toRadixString(16)).join(':');

    if (bestStart == 0 && bestLength == groups.length) {
      return '::';
    }
    if (bestStart == 0) {
      return '::$tail';
    }
    if (bestStart + bestLength == groups.length) {
      return '$head::';
    }

    return '$head::$tail';
  }
}
