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
    bool expired = false;
    final Future<HttpClientRequest> requestOpeningFuture = _client.getUrl(uri).then((request) {
      if (expired) {
        request.done.ignore();
        request.abort();
      }

      return request;
    });
    late final HttpClientRequest request;

    try {
      request = await requestOpeningFuture.timeout(_timeout);
    } on TimeoutException {
      expired = true;
      rethrow;
    }

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
