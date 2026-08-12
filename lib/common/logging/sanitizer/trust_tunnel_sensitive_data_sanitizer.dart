import 'dart:collection';

import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/sanitizer/text_scanner/sensitive_value_scanner.dart';

/// Sanitizes log payloads and free-form text before they are written or exported.
class TrustTunnelSensitiveDataSanitizer {
  static const mask = '*****';
  static const _emptyState = 'empty';
  static const _filledState = 'filled';
  static const _defaultDnsState = 'Default: AdGuard DNS Non-filtering';
  static const _customDnsState = 'Custom';

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
    'bypassRules',
    'bypass_rules',
    'vpnRules',
    'vpn_rules',
    'queryLog',
    'query_log',
    'source',
    'destination',
  };

  /// Rules whose values are reduced to an empty/filled placeholder in stripped logging mode.
  static const Set<String> strippedPresenceKeys = {
    'clientRandom',
    'client_random',
    'tlsPrefix',
    'tls_prefix',
    'certificate',
    'pem',
    'excludedRoutes',
    'excluded_routes',
    'initialExcludedRoutes',
    'initial_excluded_routes',
  };

  /// DNS address rules whose values are reduced to a default/custom placeholder in stripped logging mode.
  static const Set<String> strippedDnsStateKeys = {
    'dnsServers',
    'dns_servers',
    'dnsUpStreams',
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

  /// Text patterns that are additionally masked in stripped logging mode.
  static final List<RegExp> strippedMaskedTextPatterns = [
    RegExp(r'-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----', caseSensitive: false),
  ];

  const TrustTunnelSensitiveDataSanitizer();

  /// Sanitizes structured log data while preserving maps and lists for encoding.
  T? sanitizePayload<T extends Object>(T? value, LoggingSecurityType securityType) =>
      _sanitizePayload(value, securityType, _keyMatchersFor(securityType), HashSet<Object>.identity());

  /// Sanitizes text fragments by masking sensitive key-values and link patterns.
  String _sanitizeText(String value, LoggingSecurityType securityType) {
    final alwaysSanitized = _sanitizeTextByRules(
      value,
      keys: alwaysMaskedKeys,
      textPatterns: alwaysMaskedTextPatterns,
    );

    if (securityType == LoggingSecurityType.full) {
      return alwaysSanitized;
    }

    final presenceSanitized = _sanitizeKeyValues(
      alwaysSanitized,
      _SensitiveKeyMatcher(strippedPresenceKeys),
      replacement: _textPresencePlaceholder,
    );
    final dnsStateSanitized = _sanitizeKeyValues(
      presenceSanitized,
      _SensitiveKeyMatcher(strippedDnsStateKeys),
      replacement: _textDnsStatePlaceholder,
    );

    return _sanitizeTextByRules(
      dnsStateSanitized,
      keys: strippedMaskedKeys,
      textPatterns: strippedMaskedTextPatterns,
    );
  }

  T? _sanitizePayload<T extends Object>(
    T? value,
    LoggingSecurityType securityType,
    List<_SensitiveKeyMatcher> keyMatchers,
    Set<Object> visited,
  ) =>
      (switch (value) {
            null || num() || bool() || DateTime() => value,
            String() => _sanitizeText(value, securityType),
            Uri() => _sanitizeText(value.toString(), securityType),
            Object() => _sanitizeTrackedPayload(
              value,
              securityType,
              keyMatchers,
              visited,
            ),
          })
          as T?;

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
      _ => _sanitizeText(value.toString(), securityType),
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
    final presenceKeyMatcher = securityType == LoggingSecurityType.stripped
        ? _SensitiveKeyMatcher(strippedPresenceKeys)
        : null;
    final dnsStateKeyMatcher = securityType == LoggingSecurityType.stripped
        ? _SensitiveKeyMatcher(strippedDnsStateKeys)
        : null;

    for (final MapEntry(:key, :value) in value.entries) {
      final stringKey = key.toString();
      result[stringKey] = switch (securityType) {
        LoggingSecurityType.stripped when presenceKeyMatcher!.matches(stringKey) => _presencePlaceholder(value),
        LoggingSecurityType.stripped when dnsStateKeyMatcher!.matches(stringKey) => _dnsStatePlaceholder(value),
        _ when _masksKey(stringKey, keyMatchers) => mask,
        _ => _sanitizePayload(
          value,
          securityType,
          keyMatchers,
          visited,
        ),
      };
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

  String _sanitizeKeyValues(
    String value,
    _SensitiveKeyMatcher keyMatcher, {
    String Function(String value)? replacement,
  }) {
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
        ..write(replacement?.call(value.substring(valueStart, valueEnd)) ?? mask);
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

  String _presencePlaceholder(Object? value) => switch (value) {
    null => _emptyState,
    String() when value.isEmpty => _emptyState,
    Iterable<Object?>() when value.isEmpty => _emptyState,
    Map<Object?, Object?>() when value.isEmpty => _emptyState,
    _ => _filledState,
  };

  String _dnsStatePlaceholder(Object? value) => switch (value) {
    null => _defaultDnsState,
    String() when value.isEmpty => _defaultDnsState,
    Iterable<Object?>() when value.isEmpty => _defaultDnsState,
    _ => _customDnsState,
  };

  String _textPresencePlaceholder(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ||
            trimmed == 'null' ||
            trimmed == _emptyState ||
            trimmed == '[]' ||
            trimmed == '{}' ||
            trimmed == "''" ||
            trimmed == '""'
        ? _emptyState
        : _filledState;
  }

  String _textDnsStatePlaceholder(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty || trimmed == 'null' || trimmed == '[]' || trimmed == _defaultDnsState
        ? _defaultDnsState
        : _customDnsState;
  }
}

/// Matches sensitive keys in maps and in serialized `key: value` text.
final class _SensitiveKeyMatcher {
  final RegExp pattern;
  final Set<String> _normalizedKeys;

  _SensitiveKeyMatcher(Set<String> keys)
    : _normalizedKeys = keys.map(_normalizeKey).toSet(),
      pattern = _buildKeyPattern(keys);

  static String _normalizeKey(String key) => key.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toLowerCase();

  static RegExp _buildKeyPattern(Set<String> keys) {
    final patterns = keys.map(_normalizeKey).toSet().map((key) => key.split('').map(RegExp.escape).join(r'[\s_.-]*'));

    return RegExp(
      '(^|[^a-zA-Z0-9])["\\\']?(?:${patterns.join('|')})["\\\']?\\s*[:=]\\s*',
      caseSensitive: false,
      multiLine: true,
    );
  }

  bool matches(String key) => _normalizedKeys.contains(_normalizeKey(key));
}
