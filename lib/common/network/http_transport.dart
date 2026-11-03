import 'dart:async';
import 'dart:io';

import 'package:trusttunnel/common/network/models/http_client_configuration.dart';

final class HttpTransport {
  final Duration _timeout;
  final Map<String, String> _headers;
  final HttpClient _client;

  HttpTransport(HttpClientConfiguration configuration)
    : _timeout = configuration.timeout,
      _headers = configuration.headers,
      _client = (HttpClient()..connectionTimeout = configuration.timeout)..userAgent = configuration.userAgent;

  Future<HttpClientResponse> open(Uri uri) async {
    final HttpClientRequest request = await _client.getUrl(uri);
    _headers.forEach(request.headers.set);

    return request.close().timeout(
      _timeout,
      onTimeout: () {
        request.abort();

        throw TimeoutException('HTTP response headers timed out', _timeout);
      },
    );
  }

  void close() => _client.close(force: true);
}
