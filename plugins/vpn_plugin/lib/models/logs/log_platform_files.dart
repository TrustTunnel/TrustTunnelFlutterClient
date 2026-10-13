import 'package:flutter/foundation.dart';

class LogPlatformFiles {
  final List<String> value;

  const LogPlatformFiles._(this.value);

  factory LogPlatformFiles.platform(TargetPlatform platform) {
    final fileNames = switch (platform) {
      TargetPlatform.android => const ['vpn'],
      TargetPlatform.iOS || TargetPlatform.macOS => const ['app', 'extension'],
      TargetPlatform.windows => const ['client', 'service'],
      _ => throw UnsupportedError('Unsupported platform: $platform'),
    };

    return LogPlatformFiles._(fileNames);
  }
}
