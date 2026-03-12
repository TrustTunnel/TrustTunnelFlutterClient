import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:punycoder/punycoder.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';

abstract final class ValidationUtils {
  static const plainRawRegex = r'^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$';

  static const firstLevelDomainRegex = r'^(?=.{1,63}$)[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$';

  static const cidrRegex = r'^[^\/]+\/\d+$';

  static const domainRawRegex =
      r'^(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))\.?$';

  static const domainWithAliasRawRegex =
      r'^(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))'
      r'(?:\|[A-Za-z0-9.-]+)?\.?$';

  static const dotRawRegex =
      r'^tls://'
      r'(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))$';

  static const dohRawRegex =
      r'^https://'
      r'(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))'
      r'(?:/[^ \t\r\n]*)?$';

  static const quicRawRegex =
      r'^quic://'
      r'(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))$';

  static const h3RawRegex =
      r'^https://'
      r'(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))'
      r'(?:/[^ \t\r\n]*)?#h3$';

  static const allowableStartRegex = r'^(tls:\/\/|https:\/\/|http:\/\/|quic:\/\/|h3:\/\/|sdns:\/\/|)';

  static final RegExp _cidrRegExp = RegExp(cidrRegex);
  static final RegExp _firstLevelDomainRegExp = RegExp(firstLevelDomainRegex);
  static final RegExp _domainRegExp = RegExp(domainRawRegex);
  static final RegExp _domainWithAliasRegExp = RegExp(domainWithAliasRawRegex);
  static final RegExp _allowableStartRegExp = RegExp(allowableStartRegex);
  static final PunycodeCodec _punycodeCodec = const PunycodeCodec();

  static String? getErrorString(
    BuildContext context,
    List<PresentationField> fieldErrors,
    PresentationFieldName fieldName,
  ) => fieldErrors.where((element) => element.fieldName == fieldName).firstOrNull?.toLocalizedString(context);

  static bool validateIpAddress(String ipAddress, {bool allowPort = true}) {
    final parsed = _splitHostAndPort(ipAddress.trim());
    if (parsed == null) {
      return false;
    }

    if (parsed.port != null && !allowPort) {
      return false;
    }

    if (!_isValidPort(parsed.port)) {
      return false;
    }

    return _isIp(parsed.host);
  }

  static bool validateServerAddress(String value, {bool allowPort = true}) {
    final parsed = _splitHostAndPort(value.trim());
    if (parsed == null) {
      return false;
    }

    if (parsed.port != null && !allowPort) {
      return false;
    }

    if (!_isValidPort(parsed.port)) {
      return false;
    }

    return _isIp(parsed.host) || validateServerHost(parsed.host);
  }

  static String normalizeServerAddress(
    String value, {
    int defaultPort = 443,
  }) {
    final parsed = _splitHostAndPort(value.trim());
    if (parsed == null) {
      throw const FormatException('Invalid server address');
    }

    if (!_isValidPort(parsed.port)) {
      throw const FormatException('Invalid port');
    }

    final host = parsed.host.trim();
    if (!(_isIp(host) || validateServerHost(host))) {
      throw const FormatException('Invalid host');
    }

    final port = parsed.port ?? defaultPort.toString();

    if (_isIpv6(host)) {
      return '[$host]:$port';
    }

    final encodedDomain = parseServerHost(host);
    if (encodedDomain != null) {
      return '$encodedDomain:$port';
    }

    return '$host:$port';
  }

  static bool validateServerHost(String host) => parseServerHost(host) != null;

  static String? parseServerHost(String host) => _parseDomain(
    host.trim(),
    allowFirstLevel: true,
    allowPort: false,
    acceptWildCard: false,
    acceptLeadingDot: false,
    acceptAlias: false,
  );

  static bool validateDnsServer(String value) {
    final rawValue = value.trim();
    if (rawValue.isEmpty) {
      return false;
    }

    if (_looksLikeSupportedDnsUri(rawValue)) {
      final uri = Uri.tryParse(rawValue);
      if (uri == null) {
        return false;
      }

      if (uri.host.isEmpty) {
        return false;
      }

      if (uri.hasPort && !_isValidPort(uri.port.toString())) {
        return false;
      }

      return _isIp(uri.host) || tryParseDomain(uri.host) != null;
    }

    return validateServerAddress(rawValue);
  }

  static bool validateCidr(String cidr) {
    if (!_cidrRegExp.hasMatch(cidr)) {
      return false;
    }

    final split = cidr.split('/');
    final ipPart = split.first;
    final postfixPart = split.elementAtOrNull(1) ?? '';
    final postfix = int.tryParse(postfixPart);

    if (postfix == null || postfixPart.length != postfix.toString().length) {
      return false;
    }

    if (!_isIp(ipPart)) {
      return false;
    }

    return _isIpv6(ipPart) ? postfix >= 0 && postfix <= 128 : postfix >= 0 && postfix <= 32;
  }

  static String? tryParseDomain(
    String domain, {
    bool allowFirstLevel = false,
    bool allowPort = false,
    bool acceptWildCard = true,
  }) => _parseDomain(
    domain,
    allowFirstLevel: allowFirstLevel,
    allowPort: allowPort,
    acceptWildCard: acceptWildCard,
    acceptLeadingDot: acceptWildCard,
    acceptAlias: true,
  );

  static bool tryParseFirstLevelDomain(String domain) => _firstLevelDomainRegExp.hasMatch(domain);

  static _HostPort? _splitHostAndPort(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('[')) {
      final closingIndex = value.indexOf(']');
      if (closingIndex == -1) {
        return null;
      }

      final host = value.substring(1, closingIndex);
      final rest = value.substring(closingIndex + 1);

      if (host.isEmpty) {
        return null;
      }

      if (rest.isEmpty) {
        return _HostPort(host: host);
      }

      if (!rest.startsWith(':')) {
        return null;
      }

      final port = rest.substring(1);
      if (port.isEmpty) {
        return null;
      }

      return _HostPort(host: host, port: port);
    }

    final colonCount = ':'.allMatches(value).length;

    if (colonCount == 0) {
      return _HostPort(host: value);
    }

    if (colonCount == 1) {
      final index = value.lastIndexOf(':');
      final host = value.substring(0, index);
      final port = value.substring(index + 1);

      if (host.isEmpty || port.isEmpty) {
        return null;
      }

      return _HostPort(host: host, port: port);
    }

    return _HostPort(host: value);
  }

  static bool _isValidPort(String? port) {
    if (port == null) {
      return true;
    }

    final parsed = int.tryParse(port);

    return parsed != null && parsed >= 1 && parsed <= 65535;
  }

  static bool _isIp(String value) => InternetAddress.tryParse(value) != null;

  static bool _isIpv6(String value) => InternetAddress.tryParse(value)?.type == InternetAddressType.IPv6;

  static bool _looksLikeSupportedDnsUri(String value) => _allowableStartRegExp.hasMatch(value);

  static String? _parseDomain(
    String domain, {
    required bool allowFirstLevel,
    required bool allowPort,
    required bool acceptWildCard,
    required bool acceptLeadingDot,
    required bool acceptAlias,
  }) {
    var value = domain.trim();
    if (value.isEmpty) {
      return null;
    }

    final parsed = _splitHostAndPort(value);
    if (parsed == null) {
      return null;
    }

    if (parsed.port != null) {
      if (!allowPort || !_isValidPort(parsed.port)) {
        return null;
      }
      value = parsed.host;
    }

    var hasWildcard = false;
    const wildcard = '*.';

    if (acceptWildCard && value.startsWith(wildcard)) {
      hasWildcard = true;
      value = value.substring(wildcard.length);
    } else if (acceptLeadingDot && value.startsWith('.')) {
      value = value.substring(1);
    }

    if (value.isEmpty) {
      return null;
    }

    final encodedDomain = _punycodeCodec.encode(value);

    final isValidDomain = (acceptAlias ? _domainWithAliasRegExp : _domainRegExp).hasMatch(encodedDomain);

    final isValidFirstLevel = allowFirstLevel && tryParseFirstLevelDomain(encodedDomain);

    if (!isValidDomain && !isValidFirstLevel) {
      return null;
    }

    return hasWildcard ? '$wildcard$encodedDomain' : encodedDomain;
  }
}

final class _HostPort {
  final String host;
  final String? port;

  const _HostPort({
    required this.host,
    this.port,
  });
}
