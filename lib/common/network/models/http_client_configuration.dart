import 'package:flutter/foundation.dart';

@immutable
final class HttpClientConfiguration {
  final Duration timeout;
  final String userAgent;
  final Map<String, String> headers;

  HttpClientConfiguration({
    required this.timeout,
    required this.userAgent,
    required Map<String, String> headers,
  }) : headers = Map<String, String>.unmodifiable(headers);
}
