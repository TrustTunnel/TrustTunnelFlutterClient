import 'dart:collection';

import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/sanitizer/text_scanner/sensitive_value_scanner.dart';

/// Sanitizes log payloads and free-form text before they are written or exported.
class TrustTunnelSensitiveDataSanitizer {
  static const mask = '*****';

  /// Rules that are masked in all logging modes.
  static const Set<String> alwaysMaskedKeys = {
    'password',
    'pass',
    'subscription',
    'subscriptionUrl',
    'subscription_url',
    'deepLink',
    'deeplink',
    'configurationLink',
    'configuration_link',
    'addServerLink',
    'add_server_link',
  };

  /// Text patterns that are masked in all logging modes.
  static final List<RegExp> alwaysMaskedTextPatterns = [
    RegExp(r'tt://[^\s,\)\]\}]+', caseSensitive: false),
    RegExp(r'trusttunnel://[^\s,\)\]\}]+', caseSensitive: false),
    RegExp(
      r'https?://[^\s,\)\]\}]+(?:subscription|configuration|config|add-server)[^\s,\)\]\}]*',
      caseSensitive: false,
    ),
  ];

  /// Rules that are additionally masked in stripped logging mode.
  static const Set<String> strippedMaskedKeys = {
    'address',
    'serverAddress',
    'server_address',
    'ipAddress',
    'ip_address',
    'hostName',
    'hostname',
    'domain',
    'certificateDomain',
    'certificate_domain',
    'customSni',
    'custom_sni',
    'username',
    'userName',
    'login',
    'dnsServers',
    'dns_servers',
    'dnsUpStreams',
    'clientRandom',
    'client_random',
    'tlsPrefix',
    'tls_prefix',
    'certificate',
    'pem',
    'bypassRules',
    'bypass_rules',
    'vpnRules',
    'vpn_rules',
    'excludedRoutes',
    'excluded_routes',
    'queryLog',
    'query_log',
    'source',
    'destination',
  };

  /// Text patterns that are additionally masked in stripped logging mode.
  static final List<RegExp> strippedMaskedTextPatterns = [
    RegExp(r'-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----', caseSensitive: false),
  ];

  const TrustTunnelSensitiveDataSanitizer();

  /// Sanitizes structured log data while preserving maps and lists for encoding.
  Object? sanitizePayload(Object? value, LoggingSecurityType securityType) =>
      _sanitizePayload(value, securityType, _keyMatchersFor(securityType), HashSet<Object>.identity());

  /// Sanitizes text fragments by masking sensitive key-values and link patterns.
  String sanitizeText(String value, LoggingSecurityType securityType) {
    final alwaysSanitized = _sanitizeTextByRules(
      value,
      keys: alwaysMaskedKeys,
      textPatterns: alwaysMaskedTextPatterns,
    );

    if (securityType == LoggingSecurityType.full) {
      return alwaysSanitized;
    }

    return _sanitizeTextByRules(
      alwaysSanitized,
      keys: strippedMaskedKeys,
      textPatterns: strippedMaskedTextPatterns,
    );
  }

  Object? _sanitizePayload(
    Object? value,
    LoggingSecurityType securityType,
    List<_SensitiveKeyMatcher> keyMatchers,
    Set<Object> visited,
  ) => switch (value) {
    null || num() || bool() || DateTime() => value,
    String() => sanitizeText(value, securityType),
    Uri() => sanitizeText(value.toString(), securityType),
    Object() => _sanitizeTrackedPayload(
      value,
      securityType,
      keyMatchers,
      visited,
    ),
  };

  Object? _sanitizeTrackedPayload(
    Object value,
    LoggingSecurityType securityType,
    List<_SensitiveKeyMatcher> keyMatchers,
    Set<Object> visited,
  ) {
    if (!visited.add(value)) {
      return '<cycle>';
    }

    final sanitizedValue = switch (value) {
      Map<Object?, Object?>() => _sanitizeMap(
        value,
        securityType,
        keyMatchers,
        visited,
      ),
      Iterable<Object?>() =>
        value
            .map(
              (item) => _sanitizePayload(
                item,
                securityType,
                keyMatchers,
                visited,
              ),
            )
            .toList(),
      _ => sanitizeText(value.toString(), securityType),
    };

    return sanitizedValue;
  }

  Map<String, Object?> _sanitizeMap(
    Map<Object?, Object?> value,
    LoggingSecurityType securityType,
    List<_SensitiveKeyMatcher> keyMatchers,
    Set<Object> visited,
  ) {
    final result = <String, Object?>{};

    for (final MapEntry(:key, :value) in value.entries) {
      final stringKey = key.toString();
      result[stringKey] = _masksKey(stringKey, keyMatchers)
          ? mask
          : _sanitizePayload(
              value,
              securityType,
              keyMatchers,
              visited,
            );
    }

    return result;
  }

  String _sanitizeTextByRules(
    String value, {
    required Set<String> keys,
    required Iterable<RegExp> textPatterns,
  }) {
    var result = _sanitizeKeyValues(value, _SensitiveKeyMatcher(keys));

    for (final pattern in textPatterns) {
      result = result.replaceAll(pattern, mask);
    }

    return result;
  }

  String _sanitizeKeyValues(String value, _SensitiveKeyMatcher keyMatcher) {
    final result = StringBuffer();
    final scanner = SensitiveValueScanner(value, nextKeyPattern: keyMatcher.pattern);
    var offset = 0;

    for (final match in keyMatcher.pattern.allMatches(value)) {
      if (match.start < offset) {
        continue;
      }

      final valueStart = match.end;
      final valueEnd = scanner.valueEndFrom(valueStart);

      result
        ..write(value.substring(offset, match.start))
        ..write(match.group(0))
        ..write(mask);
      offset = valueEnd > valueStart ? valueEnd : valueStart;
    }

    result.write(value.substring(offset));

    return result.toString();
  }

  List<_SensitiveKeyMatcher> _keyMatchersFor(LoggingSecurityType securityType) => [
    _SensitiveKeyMatcher(alwaysMaskedKeys),
    if (securityType == LoggingSecurityType.stripped) _SensitiveKeyMatcher(strippedMaskedKeys),
  ];

  bool _masksKey(String key, Iterable<_SensitiveKeyMatcher> keyMatchers) =>
      keyMatchers.any((matcher) => matcher.matches(key));
}

/// Matches sensitive keys in maps and in serialized `key: value` text.
final class _SensitiveKeyMatcher {
  final Set<String> _normalizedKeys;
  final RegExp pattern;

  _SensitiveKeyMatcher(Set<String> keys)
    : _normalizedKeys = keys.map(_normalizeKey).toSet(),
      pattern = _buildKeyPattern(keys);

  bool matches(String key) => _normalizedKeys.contains(_normalizeKey(key));

  static String _normalizeKey(String key) => key.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase();

  static RegExp _buildKeyPattern(Set<String> keys) {
    final patterns = keys.map(_normalizeKey).toSet().map((key) => key.split('').map(RegExp.escape).join(r'[\s_.-]*'));

    return RegExp(
      '(^|[^a-zA-Z0-9])["\\\']?(?:${patterns.join('|')})["\\\']?\\s*[:=]\\s*',
      caseSensitive: false,
      multiLine: true,
    );
  }
}
