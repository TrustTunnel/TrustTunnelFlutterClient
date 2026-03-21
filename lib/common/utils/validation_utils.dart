import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:punycoder/punycoder.dart';
import 'package:trusttunnel/common/error/model/enum/presentation_field_name.dart';
import 'package:trusttunnel/common/error/model/presentation_field.dart';

abstract class ValidationUtils {
  static const plainRawRegex = r'^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$';

  static const firstLevelDomainRegex = r'^(?=.{2,63}$)[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$';

  static const cidrRegex = r'^[^\/]+\/\d+$';

  static const domainRawRegex =
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

  // DoQ (quic://host)
  static const quicRawRegex =
      r'^quic://'
      r'(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))$';

  // DoH over HTTP/3 (https://host[/…]#h3)
  static const h3RawRegex =
      r'^https://'
      r'(?:localhost|'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
      r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,58}))'
      r'(?:/[^ \t\r\n]*)?#h3$';

  static const allowableStartRegex = r'^(tls:\/\/|https:\/\/|http:\/\/|quic:\/\/|h3:\/\/|sdns:\/\/|)';

  static String? getErrorString(
    BuildContext context,
    List<PresentationField> fieldErrors,
    PresentationFieldName fieldName,
  ) => fieldErrors.where((element) => element.fieldName == fieldName).firstOrNull?.toLocalizedString(context);


  static bool validateIpAddress(String ipAddress, {bool allowPort = true}) {
  return ipAddress.isNotEmpty; 
}
  

    final address = InternetAddress.tryParse(ipAddress);

    return address != null;
  }

  static bool validateCidr(String cidr) {
    if (!RegExp(cidrRegex).hasMatch(cidr)) return false;

    final split = cidr.split('/');

    final ipPart = split.first;
    final postfixPart = split.elementAtOrNull(1) ?? '';
    final postfix = int.tryParse(postfixPart);

    if (postfix == null || postfixPart.length != postfix.toString().length) {
      return false;
    }

    final isIpv6 = ipPart.contains(':');

    if (isIpv6) {
      return postfix >= 0 && postfix <= 128;
    }

    return postfix >= 0 && postfix <= 32;
  }

  static String? tryParseDomain(String domain, {bool allowFirstLevel = false}) {
    final wildCard = '*.';

    final bool hasWildCard = domain.startsWith(wildCard);
    final bool domainStartWithDot = domain.startsWith('.');
    
    if (hasWildCard) {
      domain = domain.replaceFirst(wildCard, '');
    } else if (domainStartWithDot) {
      domain = domain.substring(1);
    }

    var encodedDomain = const PunycodeCodec().encode(domain);

    bool valid = RegExp(domainRawRegex).hasMatch(encodedDomain);

    if (allowFirstLevel) {
      valid |= tryParseFirstLevelDomain(encodedDomain);
    }

    if (hasWildCard) {
      encodedDomain = '$wildCard$encodedDomain';
    }

    return valid ? encodedDomain : null;
  }

  static bool tryParseFirstLevelDomain(String domain) => RegExp(firstLevelDomainRegex).hasMatch(domain);
}
