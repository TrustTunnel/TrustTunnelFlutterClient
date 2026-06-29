import 'dart:io';

import 'package:downloads_directory_provider/src/downloads_directory_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

final class DownloadsDirectorySourceImpl implements DownloadsDirectorySource {
  static const _channel = MethodChannel('com.adguard.downloads_directory_provider');

  const DownloadsDirectorySourceImpl();

  @override
  Future<Directory> getDirectory() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return getApplicationDocumentsDirectory();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final path = await _channel.invokeMethod<String>('getPublicDownloadsDirectory');
        if (path != null) {
          return Directory(path);
        }
      } catch (_) {
        // Fall through to path_provider if the native call fails.
      }
    }

    final directory = await getDownloadsDirectory();

    return directory ?? getTemporaryDirectory();
  }
}
