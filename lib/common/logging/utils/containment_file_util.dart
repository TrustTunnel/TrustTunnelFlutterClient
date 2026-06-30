import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

abstract class ContainmentFileUtil {
  /// Retrieves the platform-specific directory path for storing a file, and appends the given [fileName].
  ///
  /// For mobile and desktop platforms, this method uses `getApplicationSupportDirectory`
  /// from the `path_provider` package to obtain the path where application support files can be stored.
  ///
  /// If called from a web platform (`kIsWeb` is true), it throws an [UnimplementedError],
  /// as the web does not provide direct access to the file system.
  ///
  /// This method can also throw an [Exception] if there is an error retrieving the directory path.
  ///
  /// #### Windows only:
  ///
  /// `appName` is used to create a subdirectory within the `ProgramData` directory. If `null` `getApplicationSupportDirectory`
  /// will be used to get the directory path.
  ///
  /// `directoryName` requires `appName` to be provided and allows you to specify a subdirectory within the containment directory.
  ///
  /// ### Returns:
  /// A `Future<String>` that resolves to the full platform-specific file path, where the file
  /// can be stored.
  ///
  /// ### Throws:
  /// - [UnimplementedError]: If the method is called on the web platform.
  /// - [Exception]: If there is a failure while trying to retrieve the directory path on non-web platforms.
  static Future<String> getPlatformContainmentDirectoryPath(
    String fileName, {
    String? appName,
    String? directoryName,
  }) async {
    if (kIsWeb) {
      // Web platform does not support direct file system access.
      throw UnimplementedError('File containment directory is not supported on the web.');
    }

    if (appName == null && directoryName != null) {
      throw ArgumentError('appName must be provided if directoryName is provided.');
    }

    try {
      // Get the application support directory on non-web platforms.
      final Directory directory;
      if (Platform.isWindows && appName != null) {
        final programDataPath = Platform.environment['AppData'];

        final path = [
          programDataPath,
          appName,
          ?directoryName,
        ].join(Platform.pathSeparator);

        directory = Directory(path);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationSupportDirectory();
      }

      // Return the full path by appending the provided fileName.
      return '${directory.path}${Platform.pathSeparator}$fileName';
    } catch (e) {
      // If an error occurs, throw an exception with a detailed message.
      throw Exception('Failed to retrieve containment directory path: $e');
    }
  }
}
