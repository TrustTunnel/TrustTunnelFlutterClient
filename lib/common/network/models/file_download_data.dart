import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/network/models/http_client_configuration.dart';

@immutable
final class FileDownloadData {
  final HttpClientConfiguration configuration;
  final Uri uri;
  final String destinationPath;
  final int expectedSize;

  const FileDownloadData({
    required this.configuration,
    required this.uri,
    required this.destinationPath,
    required this.expectedSize,
  });
}
